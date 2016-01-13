package App::Clone::Filter;

use strict;
use warnings FATAL => 'all';

use File::Path qw(make_path);
use Storable qw(lock_nstore);
use Tie::IxHash;
use Try::Tiny;

=pod

=over

=item B<new>

Initializes the filter processor which is used to gather all filters from all
sources and build one master filter that is then passed to rsync. There are is
one required argument:

=over

=item options

This is a hashref of options to use when gathering filter files together. The
options used are:

=over

=item paths->builds

A hashref named C<paths> is expected to contain a key called C<builds> that has
the path to the build directory. This is where the host files will be
aggregated after they are collected from the source directories. If this path
does not exist then it will be created.

=item home

This is the path to the directory on the remote host that will be used to stage
things like the post-processing commands and the rsync log.

=item quiet

If this option is present and evaluates to a true value then no warnings or
diagnostics will be output during the filter gathering process.

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

    # this is where the deployment trees will be assembled
    my $builds = $options->{'paths'}->{'builds'};

    # make sure file operations do *exactly* what we say
    umask(0);

    # if the builds doesn't exist then create it
    # it's ok if this fails because it will get caught below
    try { make_path($builds, { 'mode' => oct(755) }); } catch {};

    # make sure build path exists and that it's not a directory
    die "ERROR: build path is not defined\n" unless defined($builds);
    die "ERROR: build path does not exist: ${builds}\n" unless (-e $builds);
    die "ERROR: build path is not a directory: ${builds}\n" unless (-d $builds);
    die "ERROR: build path is not writable: ${builds}\n" unless (-w $builds && -x _);

    # make sure the home path begins with a slash
    die "ERROR: home path must begin with slash: ${\$options->{'home'}}\n" unless ($options->{'home'} =~ /^\//x);

    return bless({
        '_stdout'  => $options->{'stdout'} || *STDOUT,
        '_stderr'  => $options->{'stderr'} || *STDERR,
        '_builds'  => $builds,
        '_options' => $options || {},
    }, $class);
}

=pod

=item B<run>

Given a host object, this will find all of the filter definitions in the host's
build directory and aggregate them into a master filter that can be used by
rsync when sending to the remote host.

=cut

sub run {
    my ($self, $host) = @_;

    my $sections = {};
    my $target = $self->{'_builds'} . "/" . $host->hostname();

    # all hosts get "directory /" by default unless set to not overlay
    unless ($host->flags() =~ /~/x) {
        $sections = { 'directory' => { '/' => 1 } };
    }

    # find all the custom filters and extract every section
    my $filters = $self->_get_filter_files($target);
    for my $file (@{$filters}) {
        my $result = $self->_parse_filters("${target}/${file}");
        $sections = _merge($sections, $result);
    }

    my ($directories, $exceptions, $perishables, $commands) = $self->_parse_filter_sections($host, $sections);
    my $contents = $self->_build_master_filter($directories, $exceptions, $perishables);

    # write the master filter file for rsync
    my $output_file = "${target}/filter_";
    open(my $fh, ">", $output_file) or die "could not open filter: ${output_file} for writing: $!\n";
    print $fh $contents;
    close($fh);

    # create the home path on the remote host
    try { make_path($target . $self->{'_options'}->{'home'}, { 'mode' => oct(755) }); } catch {};

    # freeze the commands for later processing
    my $commands_file = $target . $self->{'_options'}->{'home'} . '/commands';
    unless (lock_nstore($commands, $commands_file)) {
        die "could not create commands file: ${commands_file}: $!\n";
    }

    return $output_file;
}

sub _get_filter_files {
    my ($self, $path) = @_;

    # filter files begin with the word "filter."
    opendir(my $dh, $path) or die "could not open directory: ${path}: $!\n";
    my @filter_files = grep { $_ =~ /^filter\./x } readdir($dh);
    closedir($dh);

    return \@filter_files;
}

sub _parse_filters {
    my ($self, $file) = @_;
    print { $self->{'_stdout'} } "=> reading filter: ${file}\n" unless $self->{'_options'}->{'quiet'};

    my $sections = {};

    # remember which section we are currently reviewing in the loop
    # because things will be put into the previous section found
    my $section = undef;
    my $label = undef;

    ## no critic (RequireBriefOpen)
    open(my $fh, '<', $file) or die "could not open ${file} for reading: $!\n";
    while (my $line = <$fh>) {
        chomp($line);
        $line =~ s/^\s+//x;
        $line =~ s/\s+$//x;
        next unless length($line);
        next if (substr($line, 0, 1) eq '#');

        if ($line =~ /^=(\w+)(.*)/x) {
            $section = lc($1);
            if ($2) {
                $label = $2;
                $label =~ s/^\s+//x;
                $label =~ s/\s+$//x;

                unless ($sections->{$section}->{$label}) {
                    tie(my %h, 'Tie::IxHash');
                    $sections->{$section}->{$label} = \%h;
                }
            } else {
                $label = undef;
                unless ($sections->{$section}) {
                    tie(my %h, 'Tie::IxHash');
                    $sections->{$section} = \%h;
                }
            }
        } else {
            if (defined($section)) {
                if (defined($label)) {
                    # handles commands because commands must have labels
                    $sections->{$section}->{$label}->{$line} = 1;
                } else {
                    # handles excepts and directories
                    $sections->{$section}->{$line} = 1;
                }
            }
        }
    }
    close($fh);

    return $sections;
}

sub _parse_filter_sections {
    my ($self, $host, $sections) = @_;

    # remove anything from "except" and "perishable" that appears in "noexcept"
    if (defined($sections->{'noexcept'})) {
        for (keys %{$sections->{'noexcept'}}) {
            delete($sections->{'except'}->{$_}) if exists($sections->{'except'}->{$_});
            delete($sections->{'perishable'}->{$_}) if exists($sections->{'perishable'}->{$_});
        }
    }

    # remove any directories that appear in "nodirectory"
    if (defined($sections->{'nodirectory'})) {
        for (keys %{$sections->{'nodirectory'}}) {
            delete($sections->{'directory'}->{$_}) if exists($sections->{'directory'}->{$_});
        }
    }

    my @excepts = ();
    if (defined($sections->{'except'})) {
        push(@excepts, $_) for (keys %{$sections->{'except'}});
    }

    my @perishables = ();
    if (defined($sections->{'perishable'})) {
        push(@perishables, $_) for (keys %{$sections->{'perishable'}});
    }

    my @directories = ();
    if (defined($sections->{'directory'})) {
        push(@directories, $_) for (keys %{$sections->{'directory'}});
    }

    my $commands = {};
    while (my ($tag, $list) = each(%{$sections->{'command'}})) {
        my @files = keys %{$list};
        $commands->{$tag} = [];
        push(@{$commands->{$tag}}, $_) for (sort @files);
    }

    # we need to find any directories that have been excepted that don't exist
    # and create them or else rsync will try to remove them on the remote side
    # which is basically the exact opposite of what we want to happen.
    for my $exception (@excepts) {
        if ($exception =~ /\//x) {
            my $path = $exception;

            $path =~ s/[^\/]*[\[*?].*//x;  # strip to shortest path that has no pattern
            $path =~ s/\/[^\/]*$//x;       # strip everything after last slash
            next unless $path;             # only proceed if something is left

            my $target = $self->{'_builds'} . "/" . $host->hostname() . $path;
            unless (-e $target || -l $target) {
                # but also print it to the log
                print { $self->{'_stdout'} } "Creating ${path} to satisfy exception\n";

                # because the path will be removed from the remote side in the
                # event that the exception doesn't exist on the local side, we
                # want to die if the directory is not successfully created.
                try { make_path($target, { 'mode' => oct(755) }); } catch {};
                die "ERROR: could not create ${target} to satisfy exception\n" unless (-e $target);
            }
        }
    }

    return (\@directories, \@excepts, \@perishables, $commands);
}

sub _build_master_filter {
    my ($self, $directories, $exceptions, $perishables) = @_;

    # for the record: ORDER MATTERS
    my $x = "";

    # add exceptions
    # these are things that will be ignored on both sides
    for (@{$exceptions}) {
        $x .= "- $_\n";
    }

    # add perishables
    # these are things that will be ignored in directories that are being
    # deleted. that is if a directory has been deleted on ref and needs to be
    # removed from the remote system but it contains files that are excepted
    # then the directory will not be removed. but if the directory contains
    # files that are marked perishable then the directory will be removed along
    # with the things inside it that were marked perishable.
    for (@{$perishables}) {
        $x .= "-p $_\n";
    }

    # add directories that will be kept synchronized
    # these are things that will be kept 100% synced between the ref and the
    # remote host. anything that is added and removed on ref will be added and
    # removed on the remote host. if a file appears on the remote host that is
    # not found on ref then the file will be removed from the remote host.
    for (@{$directories}) {
        $_ =~ s/\/$//x; # remove trailing slash
        $x .= "risk $_/***\n";
    }

    # protect everything else
    # everything that is not at "risk" will be protected from being deleted
    $x .= "protect /***\n";

    return $x;
}

# stolen from Hash::Merge::Simple who stole it from Catalyst::Utils
sub _merge {
    my ($x, @y) = @_;

    return $x unless scalar(@y);
    return _merge($x, _merge(@y)) if scalar(@y) > 1;

    my ($y) = @y;
    my %merge = %{$x};

    for my $key (keys %{$y}) {
        my ($hr, $hl) = map { ref $_->{$key} eq 'HASH' } $y, $x;

        if ($hr and $hl) {
            $merge{$key} = _merge($x->{$key}, $y->{$key});
        } else {
            $merge{$key} = $y->{$key};
        }
    }

    return \%merge;
}

=pod

=back

=cut

1;
