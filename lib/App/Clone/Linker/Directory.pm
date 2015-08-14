package App::Clone::Linker::Directory;

use strict;
use warnings FATAL => 'all';

use File::Path;

=pod

=over

=item B<new> directory

This will create a new directory object that represents all files, directories,
and symbolic links in the directory it represents. This method only takes one
argument:

=over

=item directory

This is the name of the directory that this object represents.

=back

=cut

sub new {
    my ($class, $directory, $options) = @_;

    # when sources have conflicting types this determines which takes
    # precedence:
    # - "directory" is to always choose the first directory
    # - "first" is to always choose the first one found, assuming directories
    #   are in order already

    return bless({
        '_dir'     => $directory,
        '_data'    => {},
        '_options' => $options,
    }, $class);
}

=pod

=item B<get_entries>

Returns an arrayref of all files, directories, and symbolic links in this
directory.

=cut

sub get_entries {
    my $self = shift;
    return [ keys %{$self->{'_data'}} ];
}

=pod

=item B<add_entry> name info

Adds a new file, directory, or symbolic link into this directory. This method
requires the name of the object and a hash of all information necessary to
recreate the object. That varies by object type.

=over

=item directory

Requires these options:

=over

=item I<type> set to 'D' if the object is a directory

=item I<source> the source directory from where the directory came

=item I<mode> the octal permissions for the directory

=item I<uid> the numeric user id for the directory

=item I<gid> the numeric group id for the directory

=back

=item symbolic link

Requires these options:

=over

=item I<type> set to 'S' if the object is a symbolic link

=item I<source> the source directory from where the symbolic link came

=item I<ltart> the value of the symbolic link as returned by L<readlink>

=back

=item file

Requires these options:

=over

=item I<type> set to 'F' if the object is a file

=item I<source> the source directory from where the symbolic link came

=item I<ino> the inode of the original file

=back

=item unknown

Requires these options:

=over

=item I<type> set to 'U' if the type of object is unknown

=item I<source> the source directory from where the symbolic link came

=back

=back

=cut

sub add_entry {
    my ($self, $name, %info) = @_;
    return unless $name;
    return unless $info{'type'};

    $info{'isfile'} = ($info{'type'} eq 'F' ? 1 : 0);
    $info{'isdir'}  = ($info{'type'} eq 'D' ? 1 : 0);
    $info{'islink'} = ($info{'type'} eq 'S' ? 1 : 0);
    $info{'isnone'} = ($info{'type'} eq 'U' ? 1 : 0);

    push(@{$self->{'_data'}->{$name}}, \%info);
    return;
}

=pod

=item B<find_dir_entry> name

Given a name representing a directory in the current directory, this will
return the source directory from where the named directory originates. If the
name does not represent a directory or the directory is not found then nothing
will be returned. If multiple sources contain the same directory then only one
will be returned and it is not guaranteed to be the same one every time.

=cut

sub find_dir_entry {
    my ($self, $name) = @_;
    return unless $name;
    return unless $self->{'_data'}->{$name};
    return unless scalar(@{$self->{'_data'}->{$name}});

    # if we have a path name that appears in multiple sources when running in
    # precedence mode then we assume that sources are in precedence order. that
    # means that the first one to appear is the one we want to use.
    #
    # but if we are running in default "best effort" mode then if the path
    # name appears in multiple sources we should find the first one that is a
    # directory and use that one.

    # if there is only one entry or if we are in precedence mode then return
    # then first entry always.
    if ($self->{'_options'}->{'link-method-precedence'} || scalar(@{$self->{'_data'}->{$name}}) == 1) {
        my $entry = $self->{'_data'}->{$name}->[0];
        return $entry if $entry->{'isdir'};
        return;
    }

    # if we are in default "best effort" mode then return the first entry that
    # is a directory.
    for (@{$self->{'_data'}->{$name}}) {
        return $_ if $_->{'isdir'};
    }

    # if multiple entries are found and no entry is a directory then return
    # nothing.
    return;
}

=pod

=item B<find_file_entry> name

Given a name representing a file in the current directory, this will return the
source directory from where the file originates. If the name does not represent
a file or the file is not found then nothing will be returned. If multiple
sources contain the same file then only one will be returned and it is not
guaranteed to be the same one every time.

=cut

sub find_file_entry {
    my ($self, $name) = @_;
    return unless $name;
    return unless $self->{'_data'}->{$name};
    return unless scalar(@{$self->{'_data'}->{$name}});

    # for file always use the first entry
    my $entry = $self->{'_data'}->{$name}->[0];
    return $entry if $entry->{'isfile'};
    return;
}

=pod

=item B<find_link_entry> name

Given a name representing a symbolic link in the current directory, this will
return the source directory from where the symbolic link originated. If the
name does not represent a symbolic link or the symbolic link is not found then
nothing will be returned. If multiple sources contain the same symbolic link
then only one will be returned and it is not guaranteed to be the same one
every time.

=cut

sub find_link_entry {
    my ($self, $name) = @_;
    return unless $name;
    return unless $self->{'_data'}->{$name};
    return unless scalar(@{$self->{'_data'}->{$name}});

    # for link always use the first entry
    my $entry = $self->{'_data'}->{$name}->[0];
    return $entry if $entry->{'islink'};
    return;
}

=pod

=item B<get_entry_count> name

Returns the number of source directories in which the named object appears.

=cut

sub get_entry_count {
    my ($self, $name) = @_;
    return 0 unless exists($self->{'_data'}->{$name});
    return scalar(@{$self->{'_data'}->{$name}});
}

=pod

=item B<is_entry_all_same_type> name

Returns a true value if the named object is the same type (file, directory,
symbolic link) in all source directories.

=cut

sub is_entry_all_same_type {
    my ($self, $name) = @_;
    return unless exists($self->{'_data'}->{$name});

    my $type = $self->{'_data'}->{$name}->[0]->{'type'};
    for (@{$self->{'_data'}->{$name}}) {
        return 0 if $_->{'type'} ne $type;
    }
    return 1;
}

=pod

=item B<is_entry_conflicted> name

Returns a true value if the given name is in conflict. A conflict is defined
as: (1) the name exists in this directory and (2) the name appears in two or
more sources. If the name is a directory in all sources then there is no
conflict unless permissions or ownership differs between two or more sources.

=cut

sub is_entry_conflicted {
    my ($self, $name) = @_;
    return unless exists($self->{'_data'}->{$name});

    # not conflicted if only one
    return 0 if ($self->get_entry_count($name) <= 1);

    # the conditional is written this way to illustrate all cases are covered
    if ($self->is_entry_all_same_type($name)) {
       # same type ok for dir but check perms
       if ($self->is_entry_dir($name)) {
           my $mode = $self->{'_data'}->{$name}->[0]->{'mode'};
           my $uid = $self->{'_data'}->{$name}->[0]->{'uid'};
           my $gid = $self->{'_data'}->{$name}->[0]->{'gid'};

           for (@{$self->{'_data'}->{$name}}) {
               return 1 if $_->{'mode'} ne $mode;
               return 1 if $_->{'uid'} ne $uid;
               return 1 if $_->{'gid'} ne $gid;
           }

           # all dirs agree on perms
           return 0;
       } else {
           # same type, not dir
           return 1;
       }
    }

   # not same type
   return 1;
}

=pod

=item B<get_conflict> name

Given a name, this will return a textual description of any conflict that
exists between two or more sources for this directory. If no conflict exists
then this returns undef.

=cut

# our caller will know best how to output this so we provide only the message
sub get_conflict {
    my ($self, $name) = @_;
    return unless exists($self->{'_data'}->{$name});

    # no conflict if only one
    return if $self->get_entry_count($name) <= 1;

    my $type = undef;
    my $msg = "CONFLICT at " . $self->{'_dir'} . "/" . $name . "\n";

    for (@{$self->{'_data'}->{$name}}) {
        $type = "directory" if $_->{'isdir'};
        $type = "link"      if $_->{'islink'};
        $type = "file"      if $_->{'isfile'};
        $type = "other"     if $_->{'isnone'};

        if ($_->{'isdir'}) {
            $msg .= sprintf(
                "CONFLICT  %s is %s; %s.%s; %o\n",
                $_->{'source'} . $self->{'_dir'} . "/" . $name,
                $type,
                $_->{'uid'},
                $_->{'gid'},
                $_->{'mode'},
            );
        } else {
            $msg .= sprintf(
                "CONFLICT  %s is %s\n",
                $_->{'source'} . $self->{'_dir'} . "/" . $name,
                $type,
            );
        }
    }

    return $msg;
}

=pod

=item B<is_entry_dir> name

Given a name, this will return a true value if that name is both in this
directory and is a directory.

=cut

sub is_entry_dir {
    my ($self, $name) = @_;

    my $entry = $self->find_dir_entry($name);
    return defined($entry) ? 1 : 0;
}

=pod

=item B<is_entry_file> name

Given a name, this will return a true value if that name is both in this
directory and a file.

=cut

sub is_entry_file {
    my ($self, $name) = @_;

    my $entry = $self->find_file_entry($name);
    return defined($entry) ? 1 : 0;
}

=pod

=item B<is_entry_link> name

Given a name, this will return a true value if that name is both in this
directory and is a symbolic link.

=cut

sub is_entry_link {
    my ($self, $name) = @_;

    my $entry = $self->find_link_entry($name);
    return defined($entry) ? 1 : 0;
}

=pod

=item B<get_entry_directory_info> name

Given a name that is supposed to represent a directory, this will return all
information about the directory necessary to recreate it in a different
directory. If the name does not represent a directory then this will return
undef.

=cut

sub get_entry_directory_info {
    my ($self, $name) = @_;

    my $entry = $self->find_dir_entry($name);
    return unless defined($entry);

    my @info =  (
        $entry->{'mode'},
        $entry->{'uid'},
        $entry->{'gid'},
    );
    return \@info;
}

=pod

=item B<get_entry_file_info> name

Given a name that is assumed to represent a file, this will return all
information about the file necessary to recreate it in a different directory.
If the name does not represent a file then this will return undef.

=cut

sub get_entry_file_info {
    my ($self, $name) = @_;

    my $entry = $self->find_file_entry($name);
    return $entry->{'ino'} if defined($entry);
    return;
}

=pod

=item B<get_entry_link_info> name

Given a name that is assumed to represent a symbolic link, this will return
all information about the symbolic link necessary to recreate it in a different
directory. If the name does not represent a symbolic link then this will return
undef.

=cut

sub get_entry_link_info {
    my ($self, $name) = @_;

    my $entry = $self->find_link_entry($name);
    return $entry->{'ltarg'} if defined($entry);
    return;
}

=pod

=item B<get_entry_dir_absolute_path> name

Given a name representing a directory in the current directory, this will
return the absolute path to the source directory of the named directory. If
the name does not represent a directory then this will return undef.

=cut

sub get_entry_dir_absolute_path {
    my ($self, $name) = @_;

    my $entry = $self->find_dir_entry($name);
    return unless defined($entry);

    return $entry->{'source'} . $self->{'_dir'} . "/" . $name;
}

=pod

=item B<get_entry_file_absolute_path> name

Given a name representing a file in the current directory, this will return
the absolute path to the source directory of the named file. If the name does
not represent a file then this will return undef.

=cut

sub get_entry_file_absolute_path {
    my ($self, $name) = @_;

    my $entry = $self->find_file_entry($name);
    return unless defined($entry);

    return $entry->{'source'} . $self->{'_dir'} . "/" . $name;
}

=pod

=item B<get_entry_link_absolute_path> name

Given a name representing a symbolic link in the current directory, this will
return the absolute path to the source directory of the named symbolic link. If
the name does not represent a symbolic link then this will return undef.

=cut

sub get_entry_link_absolute_path {
    my ($self, $name) = @_;

    my $entry = $self->find_link_entry($name);
    return unless defined($entry);

    return $entry->{'source'} . $self->{'_dir'} . "/" . $name;
}

=pod

=item B<get_dir_sources> name

Given a name that is supposed to represent a directory object, this will
return an arrayref of all source directories that contain this directory. If
the name represents something other than a directory in one of the source
directories then that source directory will be ignored.

=cut

# for entries that are directories, provide a list of the source trees that
# provide it. the use is to identify the specific sources that are useful for
# directory recursion.
sub get_dir_sources {
    my ($self, $name) = @_;
    return unless exists($self->{'_data'}->{$name});

    my @sources = ();
    for (@{$self->{'_data'}->{$name}}) {
        push(@sources, $_->{'source'}) if $_->{'isdir'};
    }

    return \@sources;
}

=pod

=item B<set_mark> name

Given a name, this will mark the named object in this directory as being used.

=cut

sub set_mark {
    my ($self, $name) = @_;
    return unless $name;

    if (!exists($self->{'_data'}->{$name})) {
        $self->add_entry(
            $name,
            'source' => "MARK",
            'type'   => 'U',
        );
    }

    # keep track of mark in first entry
    $self->{'_data'}->{$name}->[0]->{'mark'} = 1;

    return;
}

=pod

=item B<clear_mark> name

Given a name, this will unmark the named object in this director as being used.

=cut

sub clear_mark {
    my ($self, $name) = @_;
    return unless exists($self->{'_data'}->{$name}) && exists($self->{'_data'}->{$name}->[0]->{'mark'});
    $self->{'_data'}->{$name}->[0]->{'mark'} = 0;
    return;
}

=pod

=item B<get_unmarked_entries>

Returns a hashref of all objects in the current directory that are not being
used. This is used to determine which files need to be removed from the remote
host.

=cut

sub get_unmarked_entries {
    my $self = shift;

    my @entries = ();
    for (keys %{$self->{'_data'}}) {
        next unless scalar(@{$self->{'_data'}->{$_}});
        if (!exists($self->{'_data'}->{$_}->[0]->{'mark'}) || $self->{'_data'}->{$_}->[0]->{'mark'} != 1) {
            push(@entries, $_);
        }
    }

    return \@entries;
}

=pod

=back

=cut

1;
