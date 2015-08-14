package App::Clone::Parser::Host;

use strict;
use warnings FATAL => 'all';

=pod

=over

=item B<new>

    my $host = App::Clone::Parser::Host->new(
        'hostname' => 'example',
        'platform' => 'debian8',
        'flags'    => 'r',
        'fqdn'     => 'foo.example.com'
        'paths'    => []
    );

Creates a new instance a host with the given arguments.

=cut

sub new {
    my $class = shift;
    my %args = @_;
    return bless({
        '_platform' => $args{'platform'},
        '_hostname' => $args{'hostname'},
        '_flags'    => $args{'flags'},
        '_fqdn'     => $args{'fqdn'},
        '_paths'    => $args{'paths'},
    }, $class);
}

=pod

=item B<hostname>

Returns the hostname of the host.

=cut

sub hostname {
    my $self = shift;
    return $self->{'_hostname'};
}

=pod

=item B<platform>

Returns the platform on which the host runs.

=cut

sub platform {
    my $self = shift;
    return $self->{'_platform'};
}

=pod

=item B<flags>

Returns a string of all of the flags for this host. You can search the string
like this:

    if ($host->flags() =~ /r/x) {
        # do something
    }

Takes no arguments.

=cut

sub flags {
    my $self = shift;
    return $self->{'_flags'};
}

=pod

=item B<fqdn>

Returns the fully qualified domain name of the host. Takes no arguments.

=cut

sub fqdn {
    my $self = shift;
    return $self->{'_fqdn'};
}

=pod

=item B<paths>

Returns all paths that this host matches relative to the root of the sources
directory. Takes no arguments.

=cut

sub paths {
    my $self = shift;
    return $self->{'_paths'} || [];
}

=pod

=back

=cut
1;
