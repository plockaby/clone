package App::Clone::Logger;

use strict;
use warnings FATAL => 'all';

use Try::Tiny;
use File::Path qw(make_path);
use POSIX qw(strftime);
use IO::Handle;

=pod

=over

=item B<new>(prefix, options)

Initializes the logging system and returns a reference to it. There are two
required arguments:

=over

=item prefix

This is a text string that will be prepended to the log file. Log files are
written in the format C<prefix_date>. The prefix should probably include the
name of the host and the type of action being performed on it.

=item options

This is a hashref of options to use when initializing the logging system. The
options used are:

=over

=item paths->logs

A hashref named C<paths> is expected to contain a key called C<logs> that has
the path to the log directory. This is where logs will be written. If this path
is not defined this method will die. If this path does not exist then it will
be created.

=item console

If this option is present and evaluates to a true value then output will be
simultaneously sent to the log file and to the console. This option uses
L<IO::Tee> so if that module is not installed then this option will have no
effect.

=back

=back

=cut

sub new {
    my ($class, $prefix, $options) = @_;

    # extract the path from the options and make sure it exists
    my $path = $options->{'paths'}->{'logs'};
    die "ERROR: could not open log file because log path is undefined\n" unless defined($path);

    # try to make the path where the file will be written. it is ok if this
    # fails and we ignore it because it will be caught below when trying to
    # actually open the log file.
    try { make_path($path, { 'mode' => oct(755) }); } catch {};

    my $date = strftime("%Y-%m-%d-%H:%M:%S", localtime);
    my $name = $prefix . '_' . $date;
    my $file = $path . '/' . $name;

    my $fh = try {
        ## no critic (RequireBriefOpen)
        open(my $temp_fh, '>', $file) or die "$!\n";
        return $temp_fh;
    } catch {
        my $error = (defined($_) ? $_ : "unknown error");
        warn "could not send logs to ${file}: ${error}\n";
    };

    my $stdout = undef;
    my $stderr = undef;

    if (defined($fh)) {
        if ($options->{'console'}) {
            # try to connect to both the console and the file simultaneously
            try {
                require IO::Tee;
                $stdout = IO::Tee->new($fh, \*STDOUT);
                $stderr = IO::Tee->new($fh, \*STDERR);
                return;
            } catch {
                warn "could not log to both ${file} and the console: could not load IO::Tee\n";

                $stdout = $fh;
                $stderr = $fh;

                return;
            };
        } else {
            # just writing to the console
            $stdout = $fh;
            $stderr = $fh;
        }
    } else {
        $file = '-';
        $stdout = \*STDOUT;
        $stderr = \*STDERR;
    }

    return bless({
        '_handle' => $fh,
        '_stdout' => $stdout,
        '_stderr' => $stderr,
        '_prefix' => $prefix, # prefix used for logname and symlink
        '_path'   => $path,   # the log directory
        '_name'   => $name,   # the log file name (basename)
        '_file'   => $file,   # the fully qualified log name (log directory + logname)
    }, $class);
}

=pod

=item B<handle>

Returns a handle to the log file currently being written to.

=cut

sub handle {
    my $self = shift;
    return $self->{'_handle'};
}

=pod

=item B<stdout>

Returns a handle to what should be used for STDOUT. This might just be STDOUT,
but it might also be a file handle or an instance of L<IO::Tee>.

=cut

sub stdout {
    my $self = shift;
    return $self->{'_stdout'};
}

=pod

=item B<stderr>

Returns a handle to what should be used for STDERR. This might just be STDERR,
but it might also be a file handle or an instance of L<IO::Tee>.

=cut

sub stderr {
    my $self = shift;
    return $self->{'_stderr'};
}

=pod

=item B<path>

Returns the path to the log file currently being written to.

=cut

sub path {
    my $self = shift;
    return $self->{'_file'};
}

=pod

=item B<name>

Returns the name to the log file currently being written to.

=cut

sub name {
    my $self = shift;
    return $self->{'_name'};
}

=pod

=item B<file>

Returns the full path and name of the log file currently being written to.

=cut

sub file {
    my $self = shift;
    return $self->{'_file'};
}

=pod

=back

=cut

1;
