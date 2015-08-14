package App::Clone::Config;

use strict;
use warnings FATAL => 'all';

use Storable qw(lock_nstore lock_retrieve);

use App::Clone::Parser;

=pod

=over

=item B<load>(file, options)

Loads the host configuration file and returns the compiled version of the
configuration. This method takes two arguments:

=over

=item file

This is the path to the hosts configuration file. This method will verify that
the file exists and is readable and will die if either is not true. The name of
this file is the root that is used when saving the compiled version. The
compiled version is named C<file.compiled>.

=item options

This is a hashref of options to use when compiling the configuration file. The
options used are:

=over

=item test

If this option is present and evaluates to a true option then no compiled
version of the configuration file will be saved.

=item quiet

If this option is present and evaluates to a true value then no warnings or
diagnostics will be output during the compilation process.

=item skip_lookups

If this option is present and evaluates to a true value then no DNS lookups
will be made when a hostname is encountered in the hosts configuration file.

=back

=back

=cut

sub load {
    my ($class, $file, $options) = @_;

    die "ERROR: hosts file does not exist: ${file}\n" unless (-e $file);
    die "ERROR: hosts file is not readable: ${file}\n" unless (-r $file);

    # initialize $options if undef
    $options ||= {};

    my $file_time = (stat $file)[9];
    my $compiled_file = "${file}.compiled";
    my $compiled_file_time = (stat $compiled_file)[9];

    # this stores the result of the parser on the hosts file
    my $parsed = undef;

    if ($options->{'test'} || !$compiled_file_time || $file_time > $compiled_file_time) {
        warn "rebuilding hosts ...\n" unless $options->{'quiet'};

        open(my $fh, "<", $file) or die "could not open ${file}: $!\n";
        my $data = do { local $/ = undef; <$fh>; };
        close($fh);

        $parsed = App::Clone::Parser->new($data, $options);
        if (defined($parsed)) {
            if ($options->{'test'}) {
                warn "not writing ${compiled_file} in test mode\n" unless $options->{'quiet'};
            } else {
                lock_nstore($parsed, $compiled_file) or die "ERROR: not able to save to ${compiled_file}: $!\n";
            }
            warn "done\n" unless $options->{'quiet'};
        } else {
            if ($compiled_file_time) {
                warn "WARNING: using previously compiled version\n" unless $options->{'quiet'};
                $parsed = lock_retrieve($compiled_file);
            } else {
                warn "ERROR: unable to parse hosts and no previous version exists\n" unless $options->{'quiet'};
                $parsed = undef;
            }
        }
    } else {
        $parsed = lock_retrieve($compiled_file);
    }

    return $parsed;
}

=pod

=back

=cut

1;
