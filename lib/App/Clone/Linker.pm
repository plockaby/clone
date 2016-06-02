package App::Clone::Linker;

use strict;
use warnings FATAL => 'all';

use Try::Tiny;
use File::Path qw(make_path remove_tree);
use File::Find ();

use App::Clone::Linker::Directory;

=pod

=over

=item B<new>

Initializes the linker which is then used to gather all of the files for a
given host. There are is one required argument:

=over

=item options

This is a hashref of options to use when linking files together. The options
used are:

=over

=item paths->sources

A hashref named C<paths> is expected to contain a key called C<sources> that
has the path to the source directory. This is where the program will look for
the files defined for the host in the host configuration file. If this path
does not exist then it will be created.

=item paths->builds

A hashref named C<paths> is expected to contain a key called C<builds> that has
the path to the build directory. This is where the host files will be
aggregated after they are collected from the source directories. If this path
does not exist then it will be created.

=item stdout

This should be a file handle to use when the linker needs to write to STDOUT.
If this is not present then STDOUT will be used directly.

=item stderr

This should be a file handle to use when the linker needs to write to STDERR.
If this is not present then STDERR will be used directly.

=back

=back

=cut

sub new {
    my ($class, $options) = @_;
    $options ||= {};

    # this is where all the source trees can be found
    my $sources = $options->{'paths'}->{'sources'};

    # this is where the deployment trees will be assembled
    my $builds = $options->{'paths'}->{'builds'};

    # make sure file operations do *exactly* what we say
    umask(0);

    # if the sources doesn't exist then create it
    # it's ok if this fails because it will get caught below
    try { make_path($sources, { 'mode' => oct(755) }); } catch {};

    # if the builds doesn't exist then create it
    # it's ok if this fails because it will get caught below
    try { make_path($builds, { 'mode' => oct(755) }); } catch {};

    # make sure source path exists and that it's a directory
    die "ERROR: source path is not defined\n" unless defined($sources);
    die "ERROR: source path does not exist: ${sources}\n" unless (-e $sources);
    die "ERROR: source path is not a directory: ${sources}\n" unless (-d $sources);
    die "ERROR: source path is not readable: ${sources}\n" unless (-r $sources && -x _);

    # make sure build path exists and that it's not a directory
    die "ERROR: build path is not defined\n" unless defined($builds);
    die "ERROR: build path does not exist: ${builds}\n" unless (-e $builds);
    die "ERROR: build path is not a directory: ${builds}\n" unless (-d $builds);
    die "ERROR: build path is not writable: ${builds}\n" unless (-w $builds && -x _);

    return bless({
        '_stdout'  => $options->{'stdout'} || *STDOUT,
        '_stderr'  => $options->{'stderr'} || *STDERR,
        '_sources' => $sources,
        '_builds'  => $builds,
        '_options' => $options || {},
        '_base'    => undef,
    }, $class);
}

=pod

=item B<run> host

Given a host object, this will find all of the host's source directories and
link them together into a build directory that is ready to be sent to the
remote host.

=cut

sub run {
    my ($self, $host) = @_;

    my $base = $self->{'_builds'} . "/" . $host->hostname();

    # if the target directory name doesn't exist then create it
    if (!(-e $base)) {
        unless (mkdir($base, oct(755))) {
            die "ERROR: not able to create ${base}: $!\n";
        }
    }

    # if the target area exists but is not a directory then die
    if (-e $base && !(-d $base)) {
        die "ERROR: not able to write to ${base}: not a directory\n";
    }

    # same target for whole run
    $self->{'_base'} = $base;

    my $sources = $self->_get_sources($host);
    die "ERROR: no valid source trees for ${\$host->hostname()}\n" unless scalar(@{$sources});

    # build the tree to deploy
    $self->_build("/", $sources);

    return;
}

sub _build {
    my ($self, $path, $sources) = @_;

    # $path is a path relative to the source directories but starts with a '/'.
    # consider it like you've chroot()'d into the source directory and $path is
    # where you are in that tree.

    # this should really never happen
    die "_build path supplied without leading /\n" unless ($path =~ /^\//x);

    # the starting case is path of "/". that works but shows up as "//" as we
    # recurse so we'll special case that here.
    $path = "" if ($path eq "/");

    my $source_tree = $self->_collect_directories($path, $sources);
    my $target_tree = $self->_collect_directories($path, [ $self->{'_base'} ]);

    for my $entry (@{$source_tree->get_entries()}) {
        # if not in precedence mode then print conflits
        if (!$self->{'_options'}->{'link-method-precedence'} && $source_tree->is_entry_conflicted($entry)) {
            my $message = $source_tree->get_conflict($entry);
            print { $self->{'_stderr'} } $message if defined($message);
        }

        if ($source_tree->is_entry_dir($entry)) {
            $self->_create_directory($source_tree, $target_tree, $path, $entry);

            # descend depth first, tightening sources to just those that
            # provided this directory. that is to say look for all sources that
            # have this entry in them and where the entry is a directory and
            # not a file or a link.
            $self->_build($path . "/" . $entry, $source_tree->get_dir_sources($entry));
        } elsif ($source_tree->is_entry_file($entry)) {
            $self->_create_file($source_tree, $target_tree, $path, $entry);
        } elsif ($source_tree->is_entry_link($entry)) {
            $self->_create_link($source_tree, $target_tree, $path, $entry);
        } else {
            print { $self->{'_stdout'} } "=> skipping ${entry} -- type unknown\n";
        }
    }

    # in target directory remove anything not referenced in sources
    for my $junk (@{$target_tree->get_unmarked_entries()}) {
        $self->_rm($self->{'_base'} . $path . "/" . $junk);
    }

    return;
}

sub _get_sources {
    my ($self, $host) = @_;

    # make sure each source directory exists and is a directory and fully
    # qualified. also remove duplicates.
    my $source_list = {};
    for my $source (map { $self->{'_sources'} . '/' . $_ } @{$host->paths()}) {
        next unless (-e $source && -r _);
        next if $source_list->{$source};
        $source_list->{$source} = 1;
    }

    return [ keys %{$source_list} ];
}

sub _collect_directories {
    my ($self, $path, $directories) = @_;
    my $d = App::Clone::Linker::Directory->new($path, $self->{'_options'});

    for my $q (@{$directories}) {
        my $dpath = $q . $path;
        next unless (-e $dpath && -d _);

        opendir(my $dh, $dpath) or die "could not open directory: ${dpath}: $!\n";
        my @entries = grep { $_ !~ /^\.+$/x } readdir($dh);
        closedir($dh) or die "could not close directory: ${dpath}: $!\n";

        for my $entry (@entries) {
            my ($ino, $mode, $uid, $gid) = ((lstat "${dpath}/${entry}")[1, 2, 4, 5]);

            if (-d _) {
                $d->add_entry(
                    $entry,
                    'source' => $q,
                    'type'   => 'D',
                    'mode'   => $mode,
                    'uid'    => $uid,
                    'gid'    => $gid,
                );
                next;
            }

            if (-l _) {
                $d->add_entry(
                    $entry,
                    'source' => $q,
                    'type'   => 'S',
                    'ltarg'  => readlink("${dpath}/${entry}"),
                );
                next;
            }

            if (-f _) {
                $d->add_entry(
                    $entry,
                    'source' => $q,
                    'type'   => 'F',
                    'ino'    => $ino,
                );
                next;
            }

            $d->add_entry(
                $entry,
                'source' => $q,
                'type'   => 'U',
            );
        }
    }

    return $d;
}

sub _create_directory {
    my ($self, $source, $target, $path, $name) = @_;

    my $target_absolute = $self->{'_base'} . $path . "/". $name;
    my ($mode, $uid, $gid) = @{$source->get_entry_directory_info($name)};

    if ($target->get_entry_count($name)) {
        if ($target->is_entry_dir($name)) {
            if (join("-", @{$target->get_entry_directory_info($name)}) ne "${mode}-${uid}-${gid}") {
                 $self->_chmod($target_absolute, $mode);
                 $self->_chown($target_absolute, $uid, $gid);
            }
            $target->set_mark($name);
            return;
        } else {
            $self->_rm($target_absolute);
        }
    }

    $self->_mkdir($target_absolute, $mode);
    $self->_chown($target_absolute, $uid, $gid);
    $target->set_mark($name);

    return;
}

sub _create_file {
    my ($self, $source, $target, $path, $name) = @_;

    my $target_absolute = $self->{'_base'} . $path . "/". $name;
    my $ino = $source->get_entry_file_info($name);

    if ($target->get_entry_count($name)) {
        if ($target->is_entry_file($name) && $target->get_entry_file_info($name) eq $ino) {
            $target->set_mark($name);
            return;
        } else {
            $self->_rm($target_absolute);
        }
    }

    $self->_link($target_absolute, $source->get_entry_file_absolute_path($name));
    $target->set_mark($name);

    return;
}

sub _create_link {
    my ($self, $source, $target, $path, $name) = @_;

    my $target_absolute = $self->{'_base'} . $path . "/". $name;
    my $ltarg = $source->get_entry_link_info($name);

    if ($target->get_entry_count($name)) {
        if ($target->is_entry_link($name) && $target->get_entry_link_info($name) eq $ltarg) {
            $target->set_mark($name);
            return;
        } else {
            $self->_rm($target_absolute);
        }
    }

    $self->_symlink($target_absolute, $ltarg);
    $target->set_mark($name);

    return;
}

sub _chown {
    my ($self, $file, $uid, $gid) = @_;

    print { $self->{'_stdout'} } "chown ${uid}.${gid} ${file}\n";
    unless (chown($uid, $gid, $file)) {
        print { $self->{'_stderr'} } "ERROR - chown ${file} failed: $!\n";
    }

    return;
}

sub _chmod {
    my ($self, $file, $mode) = @_;

    print { $self->{'_stdout'} } "chmod " . sprintf("%lo", ($mode & oct(7777))) . " ${file}\n";
    unless (chmod($mode, $file)) {
        print { $self->{'_stderr'} } "ERROR - chmod " . sprintf("%lo", ($mode & oct(7777))) . " ${file} failed: $!\n";
    }

    return;
}

sub _mkdir {
    my ($self, $dir, $mode) = @_;

    print { $self->{'_stdout'} } "mkdir ${dir}\n";
    print { $self->{'_stdout'} } "chmod " . sprintf("%lo", ($mode & oct(7777))) . " ${dir}\n";
    unless (mkdir($dir, $mode)) {
        print { $self->{'_stderr'} } "ERROR - mkdir ${dir} failed: $!\n";
    }

    return;
}

sub _link {
    my ($self, $file, $source) = @_;

    print { $self->{'_stdout'} } "ln ${source} ${file}\n";
    unless (link($source, $file)) {
        print { $self->{'_stderr'} } "ERROR - link ${source} -> ${file} failed: $!\n";
    }

    return;
}

sub _symlink {
    my ($self, $name, $target) = @_;

    print { $self->{'_stdout'} } "ln -s ${target} ${name}\n";
    unless (symlink($target, $name)) {
        print { $self->{'_stderr'} } "ERROR - symlink ${name} -> ${target} failed: $!\n";
    }

    return;
}

sub _rm {
    my ($self, $name) = @_;

    print { $self->{'_stdout'} } "rm -rf ${name}\n";

    # setting "safe" to false is "ok" because according to the docs this is all
    # that "safe" does for you:
    #
    #    In other words, the code will make no attempt to alter file
    #    permissions. Thus, if the process is interrupted, no filesystem
    #    object will be left in a more permissive mode.
    #
    # since the linker will fix any file system perissions in the nucleon, it
    # is ok to leave them all broken in the case of an error because they will
    # will be fixed later anyway.
    remove_tree($name, { 'verbose' => 0, 'safe' => 0, 'error' => \my $errors });
    if (@{$errors}) {
        for my $error (@{$errors}) {
            my ($file, $message) = %{$error};
            if ($file eq '') {
                print { $self->{'_stderr'} } "ERROR - remove_tree ${name} failed: ${message}\n";
            } else {
                print { $self->{'_stderr'} } "ERROR - remove_tree ${name} failed while removing ${file}: ${message}\n";
            }
        }
    }

    return;
}

=pod

=back

=cut

1;
