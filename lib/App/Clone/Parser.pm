package App::Clone::Parser;

use strict;
use warnings FATAL => 'all';

use Parse::RecDescent;
use Storable qw(dclone);

use App::Clone::Parser::Host;

# this global variable is referenced inside the parser. this is a strange setup
# because of the way Parse::RecDescent encapsulates the parser.
our $OPTIONS = {};

=pod

=over

=item B<new> data options

Parses the given hosts configuration file data using a recursive descent parser
with a well defined grammar. There are is two required arguments:

=over

=item data

This is the content of the configuration file to be parsed. This should be a
string.

=item options

This is a hashref of options to use when running rsync. The options used are:

=over

=item quiet

If this option is present and evaluates to a true value then no warnings or
diagnostics will be output during the compilation process.

=item skip_lookups

If this option is present and evaluates to a true value then no DNS lookups
will be made when a hostname is encountered in the hosts configuration file.

=back

=back

=cut

sub new {
    my ($class, $data, $options) = @_;
    my $self = bless({
        # key is the hostname which is the first name on the host line
        '_hosts'           => {},
        '_paths'           => {},
        # this next variable stores the names of all terminal paths.
        # paths are added to it as they are found and removed as they are used.
        # helps later determine what paths are not being used.
        '_path_names'      => {},
        '_used_path_names' => {},
        '_options'         => $options || {},
    }, $class);

    # assign the options to something where Parse::RecDescent can get it
    $OPTIONS = $options;

    my $parser = $self->_parser();
    my $parsed = $parser->parse($data);
    return unless defined($parsed);

    # process those results!
    $self->_load_results($parsed);
    return $self;
}

=pod

=item B<hostnames>

Returns the list of all hostnames found in the hosts configuration file.

=cut

sub hostnames {
    my ($self) = @_;
    my @hostnames = keys %{$self->{'_hosts'}};
    return \@hostnames;
}

=pod

=item B<host> $name

Takes a single argument: the name of the host to return. This returns a
L<App::Clone::Parser::Host> object representing the host as discovered in the
hosts configuration file.

=cut

sub host {
    my ($self, $name) = @_;
    return unless defined($name);
    return $self->{'_hosts'}->{$name};
}

sub _load_results {
    my ($self, $results) = @_;

    # find the value to _DIR_ so it can be prepended to all paths
    # this author hates special cases but here it is the first of two
    my ($dir) = grep { $_->{'key'} eq '_DIR_' } @{$results};
    my $prefix = $dir->{'values'};

    # find the value to _HOSTS_, another special case
    my ($hosts) = grep { $_->{'key'} eq '_HOSTS_'} @{$results};

    # now remove _DIR_ and _HOSTS_ from $results so we can parse out real paths
    $self->_load_paths([ grep { $_->{'key'} !~ /^(?:_DIR_|_HOSTS_)$/x } @{$results} ]);

    # now that all of the paths and variables are defined, let's load the hosts
    $self->_load_hosts($hosts);

    return;
}

sub _load_paths {
    my ($self, $results) = @_;

    for my $result (@{$results}) {
        my $path = $self->_parse_path($result);
        for my $key (keys %{$path}) {
            $self->{'_paths'}->{$key} = $path->{$key};
        }
    }

    return;
}

sub _parse_path {
    my ($self, $path, $suffixes, $paths, $parent) = @_;

    # this is the name of the path.
    my $name = $path->{'key'} || '';

    # remember the names of all paths so that later we can find out which ones
    # aren't being used. path names can be blank.
    $self->{'_path_names'}->{$name} = 1 if defined($name);

    # remove paths when they've been used
    $self->{'_used_path_names'}->{$parent} = 1 if defined($parent);

    # since this method is recursive the $suffixes variable stores all suffixes
    # in all paths to this point. if we have a suffix on this path then add it
    # to the list.
    $suffixes ||= [];
    if ($path->{'suffixes'}) {
        for my $suffix (@{$path->{'suffixes'}}) {
            push(@{$suffixes}, @{$suffix}) if $suffix;
        }
    }

    # since this method is recursive the $paths var stores all paths in all
    # paths to this point. if it's empty then give it an initial value. it
    # might come empty from a recursive call.
    $paths ||= [];

    # these are paths to pursue further.
    # this way we can give them all of the paths in their parents.
    my @further = ();

    # find all of the path values at this level and also find new tries to
    # pursue further.
    if ($path->{'values'}) {
        for my $value (@{$path->{'values'}}) {
            if ($value->{'path'}) {
                push(@{$paths}, [ $value->{'path'}, $suffixes ]);
            }
            if ($value->{'variable'}) {
                push(@{$paths}, [ $value->{'variable'}, $suffixes ]);
            }
            if ($value->{'key'}) {
                push(@further, $value);
            }
        }
    }

    # create the path from the paths collected above
    my $trees = { $name => $paths };

    # now look for subtrees to descend into, giving them all of the paths and
    # suffixes that were found for this tree
    for (@further) {
        my $subtrees = $self->_parse_path(dclone($_), dclone($suffixes), dclone($paths), $name);
        for my $subtree (keys %{$subtrees}) {
            $trees->{$subtree} = $subtrees->{$subtree};
        }
    }

    return $trees;
}

sub _load_hosts {
    my ($self, $results) = @_;

    for my $host (@{$results->{'values'}}) {
        my $hostname = $host->{'hostname'};
        my $platform = $host->{'platform'};
        my $fqdn = $host->{'fqdn'};

        # compile the list of trees into a list of paths
        my $paths = $self->_parse_path({ 'key' => $hostname, 'values' => $host->{'sources'} }, undef, undef, $hostname);
        next unless exists($paths->{$hostname});

        my @paths = ();

        # add implicit paths
        push(@paths, "${platform}/${hostname}");

        # add explicitly configured paths
        for my $path (@{$paths->{$hostname}}) {
            my $result = $self->_load_host_path($hostname, $path->[0], $path->[1]);
            push(@paths, @{$result}) if defined($result);
        }

        # remove duplicate paths
        my %seen = ();
        @paths = grep { !$seen{$_}++ } @paths;

        # create the host
        $self->{'_hosts'}->{$hostname} = App::Clone::Parser::Host->new(
            'hostname' => $hostname,
            'platform' => $platform,
            'flags'    => $host->{'flags'},
            'fqdn'     => $fqdn,
            'paths'    => [sort @paths],
        );
    }

    return;
}

sub _load_host_path {
    my ($self, $hostname, $name, $suffixes, $parents) = @_;

    # initialize parents if none exist
    $parents ||= [];

    # path name is actually a variable so expand it.
    # this match is about a billion times faster than a regular expression
    if (substr($name, 0, 1) eq '$') {
        # add this path to the list of parents
        # so a traceback can be built when debugging paths that are missing
        push(@{$parents}, $name);

        # remove leading dollar sign ($)
        # this is about a billion times faster than a regular expression.
        $name = substr($name, 1);

        my $paths = $self->{'_paths'}->{$name};
        unless ($paths) {
            warn "WARNING: could not find '${\join('\' from \'', reverse @{$parents})}' while loading ${hostname} - skipping\n" unless $self->{'_options'}->{'quiet'};
            return;
        }

        # mark that this path is being used
        $self->{'_used_path_names'}->{$name} = 1;

        my @paths = ();
        for my $path (@{$paths}) {
            my $result = $self->_load_host_path($hostname, $path->[0], $path->[1], dclone($parents));
            push(@paths, @{$result}) if defined($result);
        }
        return \@paths;
    }

    # path name is actually an implicit path.
    # append suffixes to it.
    if (substr($name, -1) eq '/') {
        my @paths = ();
        push(@paths, $name . $_) for (@{$suffixes});
        return \@paths;
    }

    return [$name];
}

sub _parser {
    return Parse::RecDescent->new(q@
        # Startup actions must be before any rules.
        {
           my %all_varnames = ();
           my %all_fqdn = ();
           my %all_hostname = ();
        }
        <warn>

        # Rules in all caps are character set definitions. Typically are mapped
        # to prettier names in other rules for prettier errors or to add
        # actions.

        # Self explanatory.
        EOF : /\Z/

        # An empty block might contain commented lines.
        EMPTY : /(\s*|#[^\n]*)*/

        # ALPHANAME must start with alpha, never '_'.
        ALPHANAME : /[a-z][\w\-\.]*/i

        # DIRECTORY_PATHs must have at least one slash or there is ambiguity
        # with variable names.
        DIRECTORY_PATH_ABS : /\/\w[\w\-\.\/]*/
        DIRECTORY_PATH_REL : /\w[\w\-\.]*\/[\w\-\.\/]*/

        # DIR_SUFFIX old parser used \w definition, must not contain '/'.
        DIR_SUFFIX: /[\w\-\.]+/

        # HOSTNAME is typically short hostname so should agree with first part
        # of FQDN.
        HOSTNAME: /[a-z][a-z0-9\-]*/i

        # FQDN don't have to be too picky, result is gethostbyname'd. This is
        # character def, see "fqdn" rule further down.
        FQDN: /[a-z][a-z0-9\-\.]+/i

        # These rules just make prettier automatic error messages.
        platform:          ALPHANAME
        directory_suffix:  DIR_SUFFIX

        # disambiguation required: paths end on whitespace, be greedy to a possible \s
        absolute_path:    DIRECTORY_PATH_ABS /\s*/ { $return = $item[1] }
        relative_path:    DIRECTORY_PATH_REL /\s*/ { $return = $item[1] }


        # For hostname we make sure it is not a duplicate. Each of the actions
        # is evaluted and if true, continues to the next. A local variable is
        # used to build custom error message.
        hostname:
            <rulevar: $my_error = "">    # This production always fails, but sets local variable
          | HOSTNAME
                { $my_error = "Duplicate hostname " . $item{'HOSTNAME'};
                  $all_hostname{$item{'HOSTNAME'}} ? undef : 1 }

                # Final action we have a good HOSTNAME, note it and return it.
                { $all_hostname{$item{'HOSTNAME'}} = 1; $return = $item{'HOSTNAME'} }

          | <error:$my_error>


        # 'r' = has no impact whatsoever but is allowed to be set
        # 'X' = will only clone if forced
        # '~' = don't delete things on the remote side
        flags:    # Here we are using lookahead for '[' in order to trap incorrect flags here rather than outer rule
            /[rZ~]*/ ...'['
                { $return = $item[1]; }
        | <error>


        # For fqdn we make sure it is in DNS, not a duplicate. Each of the
        # actions is evaluted and if true, continues to the next. A local
        # variable is used to build custom error message.
        fqdn:
            <rulevar: $my_error = "">    # This production always fails, but sets local variable
          | FQDN
                { $my_error = "Invalid FQDN: " . $item{'FQDN'} . " not found in DNS";
                  $App::Clone::Parser::OPTIONS->{'skip_lookups'} ? 1 : gethostbyname($item{'FQDN'}) ? 1 : undef }

                { $my_error = "Duplicate FQDN found " . $item{'FQDN'};
                  $all_fqdn{$item{'FQDN'}} ? undef : 1 }

                # Final action we have a good FQDN, note it and return it.
                { $all_fqdn{$item{'FQDN'}} = 1; $return = $item{'FQDN'} }

          | <error:$my_error>


        # For variable_name we make sure it is not a duplicate. Each of the
        # actions is evaluted and if true, continues to the next. A local
        # variable is used to build custom error message.
        variable_name:
            <rulevar: $my_error = "">    # This production always fails, but sets local variable
          | ALPHANAME
                { $my_error = "Duplicate variable definition " . $item{'ALPHANAME'};
                  $all_varnames{$item{'ALPHANAME'}} ? undef : 1 }

                # Final action we have a good ALPHANAME, note it and return it.
                { $all_varnames{$item{'ALPHANAME'}} = 1; $return = $item{'ALPHANAME'} }

          | <error:$my_error>


        dollar_variable:              # Expansion of variable_name
           '$' <commit> ALPHANAME
               { $return = '$'.$item{'ALPHANAME'} }
         | <error?> <reject>          # Only error if we definitely have a $ sign


        nested_host_value:
            dollar_variable
                { $return = { 'variable' => $item{'dollar_variable'} } }
          | relative_path
                { $return = { 'path' => $item{'relative_path'} } }
          | <error>


        host_value:
            dollar_variable
                { $return = [ { 'variable' => $item{'dollar_variable'} } ] }
          | relative_path
                { $return = [ { 'path' => $item{'relative_path'} } ] }
          | '{' <commit> nested_host_value(s) '}'
                 { $return = $item{'nested_host_value(s)'} }
          | <error>


        host_identifier:
            hostname '/' flags '[' platform '\@' fqdn ']'
                { $return = {
                             'hostname' => $item{'hostname'},
                             'platform' => $item{'platform'},
                             'flags'    => $item{'flags'},
                             'fqdn'     => $item{'fqdn'},
                           };
                }
          | <error>


        host:
            host_identifier '=' host_value
                # Successful host_identifier returns a Host object
                # so we'll jam the host_value into it
                { $item{'host_identifier'}->{'sources'} = $item{'host_value'};
                  $return =  $item{'host_identifier'} }
          | <error>


        directory_suffixes:
            '(' <commit> directory_suffix(s) ')'
                { $return = $item{'directory_suffix(s)'} }
          | <error?><reject>  # directory_suffixes optional: only error if committed by presence of open paren


        nested_value:
            dollar_variable
                { $return = { 'variable' => $item{'dollar_variable'} } }
          | relative_path
                { $return = { 'path' => $item{'relative_path'} } }
          | variable_name directory_suffixes(?) '=' variable_value
                { $return = { 'key' => $item{'variable_name'},
                              'suffixes' => $item{'directory_suffixes(?)'},
                              'values' => $item{'variable_value'} } }
          | <error>


        variable_value:
            dollar_variable
                { $return = [ { 'variable' => $item{'dollar_variable'} } ] }
          | relative_path
                { $return = [ { 'path' => $item{'relative_path'} } ] }
          | '{' EMPTY '}'
                { $return = [] } # Can't return undef
          | '{' nested_value(s) '}'
                { $return = $item{'nested_value(s)'} }
          | <error>


        definition:
            '_HOSTS_' <commit> '=' '{' host(s) '}'
                { $return = { 'key' => $item[1],
                              'values' => $item{'host(s)'} } }
          | '_DIR_' <commit> '=' absolute_path
                { $return = { 'key' => $item[1],
                              'values' => $item{'absolute_path'} } }
          | variable_name directory_suffixes(?) '=' variable_value
                { $return = { 'key' => $item{'variable_name'},
                              'suffixes' => $item{'directory_suffixes(?)'},
                              'values' => $item{'variable_value'} } }
          | directory_suffixes '=' variable_value
                { $return = { 'key' => '',
                              'suffixes' => [ $item{'directory_suffixes'} ],
                              'values' => $item{'variable_value'} } }
          |  <error>


        file:
            definition(s) EOF
                { $return = $item{'definition(s)'} }

        # The Parse Party starts here
        parse: <skip:'(\s+|#[^\n]*)*'> file

    @);
}

=pod

=back

=cut

1;
