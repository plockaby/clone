package App::Clone::Runner;

use strict;
use warnings FATAL => 'all';

use Try::Tiny;

=pod

=over

=item B<new> options

Initializes the runner which is then used to send the compiled and aggregated
host files to the remote host. There are is one required argument:

=over

=item options

This is a hashref of options to use when running rsync. The options used are:

=over

=item paths->builds

A hashref named C<paths> is expected to contain a key called C<builds> that has
the path to the build directory. This is where the host files will be
aggregated after they are collected from the source directories.

=item paths->tools

A hashref named C<paths> is expected to contain a key called C<tools> that has
the path to the tools directory. This is where the remote side post-processing
scripts are to be found. Everything in this directory will be copied to the
the C<tools> directory under the directory defined in the C<home> configuration
option and deployed to the remote host.

=item runner->ssh

This should be the path to C<ssh> on the local and remote host.

=item runner->rsync

This should be the path to C<rsync> on the local and remote host.

=item runner->sudo

This should be the path to C<sudo> on the remote host.

=item user

This is the name of the user to use when connecting to the remote host. This
user should have permissions to run C<sudo> on C<rsync> on the remote host.

=item home

This is the path to the directory on the remote host that will be used to stage
things like the post-processing commands and the rsync log.

=item key

This is the path to private SSH key to use when connecting to the remote host.

=item force

If this option is present and evaluates to a true value then the host will be
updated regardless of any flag preventing its update -- for example, this will
ignore the C<X> flag in the hosts configuration file.

=item paranoid

If this option is present and evaluates to a true value then rsync will enforce
checksums when synchronizing the remote host.

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

    # make sure build path exists and that it's not a directory
    my $builds = $options->{'paths'}->{'builds'};
    die "ERROR: build path is not defined\n" unless defined($builds);
    die "ERROR: build path does not exist: ${builds}\n" unless (-e $builds);
    die "ERROR: build path is not a directory: ${builds}\n" unless (-d $builds);
    die "ERROR: build path is not readable: ${builds}\n" unless (-r $builds && -x _);

    # this is where our tools come from
    my $tools = $options->{'paths'}->{'tools'};
    die "ERROR: tool path is not defined\n" unless defined($tools);
    die "ERROR: tool path does not exist: ${tools}\n" unless (-e $tools);
    die "ERROR: tool path is not a directory: ${tools}\n" unless (-d $tools);
    die "ERROR: tool path is not readable: ${tools}\n" unless (-r $tools && -x _);

    # make sure we have ssh and that we can run it
    my $ssh = $options->{'runner'}->{'ssh'};
    die "ERROR: cannot find ssh client\n" unless defined($ssh);
    die "ERROR: cannot find ssh client -- ssh executable not found: ${ssh}\n" unless (-e $ssh);
    die "ERROR: cannot find ssh client -- ssh executable is not executable: ${ssh}\n" unless (-x $ssh);

    # make sure we have rsync and that we can run it
    my $rsync = $options->{'runner'}->{'rsync'};
    die "ERROR: cannot find rsync client\n" unless defined($rsync);
    die "ERROR: cannot find rsync client -- rsync executable not found: ${rsync}\n" unless (-e $rsync);
    die "ERROR: cannot find rsync client -- rsync executable is not executable: ${rsync}\n" unless (-x $rsync);

    # make sure we have sudo and that we can run it
    my $sudo = $options->{'runner'}->{'sudo'};
    die "ERROR: cannot find sudo\n" unless defined($ssh);
    die "ERROR: cannot find sudo -- sudo executable not found: ${sudo}\n" unless (-e $sudo);
    die "ERROR: cannot find sudo -- sudo executable is not executable: ${sudo}\n" unless (-x $sudo);

    # make sure we have other config options
    die "ERROR: cannot find user -- missing 'user' in configuration file.\n" unless defined($options->{'user'});
    die "ERROR: cannot find home -- missing 'home' in configuration file.\n" unless defined($options->{'home'});

    # make sure we have a key and that it exists
    my $key = $options->{'key'};
    die "ERROR: cannot find key -- missing 'key' in configuration file.\n" unless defined($key);
    die "ERROR: cannot find key -- key not found: ${key}.\n" unless (-e $key);

    return bless({
        '_stdout'  => $options->{'stdout'} || *STDOUT,
        '_stderr'  => $options->{'stderr'} || *STDERR,
        '_builds'  => $builds,
        '_tools'   => $tools,
        '_options' => $options || {},
    }, $class);
}

=pod

=item B<verify> host

Given a host object, this will call rsync against the remote host as a dry-run
to verify what will be added or removed from the remote host.

=cut

sub verify {
    my ($self, $host) = @_;
    $self->_run($host, 0);
    return;
}

=pod

=item B<update> host

Given a host object, this will call rsync against the remote host and will
actually add or remove data from the remote host.

=cut

sub update {
    my ($self, $host) = @_;
    $self->_run($host, 1);
    return;
}

sub _run {
    my ($self, $host, $update) = @_;

    if ($host->flags() =~ /X/x && !$self->{'_options'}->{'force'}) {
        die "ERROR: host is disabled with X, probably intentionally -- force action with -f\n";
    }

    my $ssh   = $self->{'_options'}->{'runner'}->{'ssh'};
    my $sudo  = $self->{'_options'}->{'runner'}->{'sudo'};
    my $rsync = $self->{'_options'}->{'runner'}->{'rsync'};
    my $user  = $self->{'_options'}->{'user'};
    my $home  = $self->{'_options'}->{'home'};
    my $key   = $self->{'_options'}->{'key'};

    # make sure we have something to sync
    my $builds = $self->{'_builds'} . "/" . $host->hostname();
    die "ERROR: cannot find builds directory to sync from: ${builds}\n" unless (-e $builds);
    die "ERROR: cannot read builds directory: ${builds}\n" unless (-d _ && -r _ && -x _);

    # make sure we have tools to copy
    my $tools = $self->{'_tools'};

    # move over the tools
    try {
        print { $self->{'_stdout'} } "copying contents of ${tools} to ${builds}${home}/tools\n";
        my $command = "${rsync} -rlptgoDzhOJH --numeric-ids --delete-during ${tools} ${builds}${home} 2>&1";
        open(my $fh, '-|', $command) or die "could not start ${rsync}: $!\n";
        while (<$fh>) { print { $self->{'_stdout'} } "syncing tools: ${_}" }
        close($fh);

        my $status = $? >> 8;
        print { $self->{'_stderr'} } "rsync returned error code ${status}: $!\n" if ($status);
    } catch {
        my $error = (defined($_) ? $_ : "unknown error");
        die "call to rsync produced an error: ${error}\n";
    };

    # sync things
    {
        # rsync options:
        # -r  recurse into subdirectories
        # -l  copy symlinks as symlinks
        # -p  preserve permissions
        # -t  preserve modification times
        # -g  preserve group
        # -o  preserve owner
        # -D  preserve device files and special files
        # -z  compress file data during the transfer
        # -h  enable human readable output for file sizes
        # -i  output a change summary for all updates
        # -O  omit directories from --times
        # -J  omit symlinks from --times (only available in rsync 3.1.0 and greater)
        # -H  copy hard links as hard links
        # -n  dry-run only
        # --checksum
        #     use MD5 checksums to determine which files have changed
        # --numeric-ids
        #     don't map uid/gid values by user/group name
        # --stats
        #     give some file-transfer stats
        # --delete-during
        #     deletes files incrementally as the transfer happens. a per directory
        #     scan is done before each directory is checked for updates and that
        #     is when deletes happen

        # order of exclude/filter options is IMPORTANT
        my $command = "${rsync} -rlptgoDzhiOJH --numeric-ids --stats ";
        $command .= "-n " unless ($update);
        $command .= "--checksum " if ($self->{'_options'}->{'paranoid'});
        $command .= "--delete-during ";
        $command .= "--rsh=\"${ssh} -l ${user} -i ${key}\" ";
        $command .= "--exclude=${home}/updates ";
        $command .= "--filter=\"merge ${builds}/filter_\" ";
        $command .= "--rsync-path=\"${sudo} ${rsync} --log-file=${home}/updates\" ";
        $command .= "${builds}/./ ${\$host->fqdn()}:/ ";
        $command .= "2>&1";

        try {
            print { $self->{'_stdout'} } "Starting rsync: ${command}\n";
            open(my $fh, '-|', $command) or die "could not start ${rsync}: $!\n";
            while (<$fh>) { print { $self->{'_stdout'} } $_ }
            close($fh);

            my $status = $? >> 8;
            print { $self->{'_stderr'} } "rsync returned error code ${status}: $!\n" if ($status);
        } catch {
            my $error = (defined($_) ? $_ : "unknown error");
            die "call to rsync produced an error: ${error}\n";
        };
    }

    # run remote commands
    if ($update) {
        my $command = "${ssh} -l ${user} -i ${key} ${\$host->fqdn()} ${sudo} ${home}/tools/process-updates ";
        $command .= "--updates=${home}/updates ";
        $command .= "--commands=${home}/commands ";
        $command .= "--scripts=${home}/tools/scripts ";
        $command .= "2>&1";

        try {
            print { $self->{'_stdout'} } "Starting post processing: ${command}\n";
            open(my $fh, '-|', $command) or die "could not start post processing: $!\n";
            while (<$fh>) { print { $self->{'_stdout'} } $_ }
            close($fh);

            my $status = $? >> 8;
            print { $self->{'_stderr'} } "process-updates returned error code ${status}: $!\n" if ($status);
        } catch {
            my $error = (defined($_) ? $_ : "unknown error");
            die "call to remote process-updates produced an error: ${error}\n";
        };
    }

    return;
}

=pod

=back

=cut

1;
