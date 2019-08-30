#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';

use Test::More;

use_ok("App::Clone::Parser") or BAIL_OUT("cannot test App::Clone::Parser as it is not compiling correctly");

my $parser = undef;
my $result = undef;

# _parser has to be called each time since there is global state
# which must be reset for each test to work right.

$parser = App::Clone::Parser::_parser();
$App::Clone::Parser::OPTIONS = { 'skip_lookups' => 1 };
$result = $parser->parse(q|
    _HOSTS_ = {
        aca-test1/r [debian8 @foo.example.com] = $ACATEST_RHEL6_NS
    }
|);
is_deeply($result, [
          {
            'values' => [
                         {
                           'fqdn' => 'foo.example.com',
                           'platform' => 'debian8',
                           'sources' => [
                                          {
                                            'variable' => '$ACATEST_RHEL6_NS'
                                          }
                                        ],
                           'flags' => 'r',
                           'hostname' => 'aca-test1',
                           'port' => 22,
                         }
                       ],
            'key' => '_HOSTS_'
          }
], "host line 1");


$parser = App::Clone::Parser::_parser();
$App::Clone::Parser::OPTIONS = { 'skip_lookups' => 1 };
$result = $parser->parse(q|
    _HOSTS_ = {
        agora/r [debian8 @bar.example.com] = {
            $STUDENTTEAM_RHEL6_NS
        }
    }
|);
is_deeply($result, [
          {
            'values' => [
                         {
                           'fqdn' => 'bar.example.com',
                           'platform' => 'debian8',
                           'sources' => [
                                          {
                                            'variable' => '$STUDENTTEAM_RHEL6_NS'
                                          }
                                        ],
                           'flags' => 'r',
                           'hostname' => 'agora',
                           'port' => 22,
                         }
                       ],
            'key' => '_HOSTS_'
          }
], "host equals block 1");


$parser = App::Clone::Parser::_parser();
$App::Clone::Parser::OPTIONS = { 'skip_lookups' => 1 };
$result = $parser->parse(q|
    _HOSTS_ = {
        agora/r [debian8 @bar.example.com] = {
            $STUDENTTEAM_RHEL6_NS
            rhel6/package
            $VI_CLIENT_TOOLS_261974_RHEL6
        }
    }
|);
is_deeply($result, [
          {
            'values' => [
                         {
                           'fqdn' => 'bar.example.com',
                           'platform' => 'debian8',
                           'sources' => [
                                          {
                                            'variable' => '$STUDENTTEAM_RHEL6_NS'
                                          },
                                          {
                                            'path' => 'rhel6/package'
                                          },
                                          {
                                            'variable' => '$VI_CLIENT_TOOLS_261974_RHEL6'
                                          }
                                        ],
                           'flags' => 'r',
                           'hostname' => 'agora',
                           'port' => 22,
                         }
                       ],
            'key' => '_HOSTS_'
          }
], "host equals block 2");


$result = App::Clone::Parser->new(q|
    _HOSTS_ = {
        zzz/r [debian8 @localhost] = {}
    }
|);
ok(!defined($result), "host equals block empty block");


# this implicit path is meaningless and really shouldn't be allowed
$parser = App::Clone::Parser::_parser();
$App::Clone::Parser::OPTIONS = { 'skip_lookups' => 1 };
$result = $parser->parse(q|
    _HOSTS_ = {
        agora/r [debian8 @bar.example.com] = rhel6/
    }
|);
is_deeply($result, [
          {
            'values' => [
                         {
                           'fqdn' => 'bar.example.com',
                           'platform' => 'debian8',
                           'sources' => [
                                          {
                                            'path' => 'rhel6/'
                                          }
                                        ],
                           'flags' => 'r',
                           'hostname' => 'agora',
                           'port' => 22,
                         }
                       ],
            'key' => '_HOSTS_'
          }
], "host equals implicit path");


$parser = App::Clone::Parser::_parser();
$App::Clone::Parser::OPTIONS = { 'skip_lookups' => 1 };
$result = $parser->parse(q|
    _HOSTS_ = {
        agora/r [debian8 @bar.example.com] = rhel6/asdf
    }
|);
is_deeply($result, [
          {
            'values' => [
                         {
                           'fqdn' => 'bar.example.com',
                           'platform' => 'debian8',
                           'sources' => [
                                          {
                                            'path' => 'rhel6/asdf'
                                          }
                                        ],
                           'flags' => 'r',
                           'hostname' => 'agora',
                           'port' => 22,
                         }
                       ],
            'key' => '_HOSTS_'
          }
], "host equals explicit path");


$parser = App::Clone::Parser::_parser();
$App::Clone::Parser::OPTIONS = { 'skip_lookups' => 1 };
$result = $parser->parse(q|
    _HOSTS_ = {
          ad-dbdev-uwtc-21/r [debian8 @baz.example.com] = $NETDB_LNX5-64_NS_PROD
    }
|);
is_deeply($result, [
          {
            'values' => [
                         {
                           'fqdn' => 'baz.example.com',
                           'platform' => 'debian8',
                           'sources' => [
                                          {
                                            'variable' => '$NETDB_LNX5-64_NS_PROD'
                                          }
                                        ],
                           'flags' => 'r',
                           'hostname' => 'ad-dbdev-uwtc-21',
                           'port' => 22,
                         }
                       ],
            'key' => '_HOSTS_'
          }
], "host equals variable");


$parser = App::Clone::Parser::_parser();
$App::Clone::Parser::OPTIONS = { 'skip_lookups' => 0 };
$result = $parser->parse(q|
    _HOSTS_ = {
          ad-dbdev-uwtc-21/r [debian8 @bad-name-here] = $NETDB_LNX5-64_NS_PROD
    }
|);
ok(!defined($result), "bad fqdn");


$parser = App::Clone::Parser::_parser();
$App::Clone::Parser::OPTIONS = { 'skip_lookups' => 0 };
$result = $parser->parse(q|
    _HOSTS_ = {
          ad-dbdev-uwtc-21/r [debian8 @ref..com] = $NETDB_LNX5-64_NS_PROD
    }
|);
ok(!defined($result), "bad fqdn 2");


$parser = App::Clone::Parser::_parser();
$App::Clone::Parser::OPTIONS = { 'skip_lookups' => 0 };
$result = $parser->parse(q|
    _HOSTS_ = {
          ad-dbdev-uwtc-21/r [debian8 @] = $NETDB_LNX5-64_NS_PROD
    }
|);
ok(!defined($result), "bad fqdn 3");


$parser = App::Clone::Parser::_parser();
$App::Clone::Parser::OPTIONS = { 'skip_lookups' => 1 };
$result = $parser->parse(q|
    _HOSTS_ = {
          ad-dbdev-uwtc-21 [debian8 @asdf.example.com] = $NETDB_LNX5-64_NS_PROD
    }
|);
ok(!defined($result), "missing flag separator");


$parser = App::Clone::Parser::_parser();
$App::Clone::Parser::OPTIONS = { 'skip_lookups' => 1 };
$result = $parser->parse(q|
    _HOSTS_ = {
          ad-dbdev-uwtc-21/Q [debian8 @asdf.example.com] = $NETDB_LNX5-64_NS_PROD
    }
|);
ok(!defined($result), "bad flag 1");


$parser = App::Clone::Parser::_parser();
$App::Clone::Parser::OPTIONS = { 'skip_lookups' => 1 };
$result = $parser->parse(q|
    _HOSTS_ = {
          ad-dbdev-uwtc-21/0 [debian8 @asdf.example.com] = $NETDB_LNX5-64_NS_PROD
    }
|);
ok(!defined($result), "bad flag 2");


$parser = App::Clone::Parser::_parser();
$App::Clone::Parser::OPTIONS = { 'skip_lookups' => 1 };
# it is okay to have no flags, but must have separator
$result = $parser->parse(q|
    _HOSTS_ = {
          ad-dbdev-uwtc-21/ [debian8 @baz.example.com] = $NETDB_LNX5-64_NS_PROD
    }
|);
is_deeply($result, [
          {
            'values' => [
                         {
                           'fqdn' => 'baz.example.com',
                           'platform' => 'debian8',
                           'sources' => [
                                          {
                                            'variable' => '$NETDB_LNX5-64_NS_PROD'
                                          }
                                        ],
                           'flags' => '',
                           'hostname' => 'ad-dbdev-uwtc-21',
                           'port' => 22,
                         }
                       ],
            'key' => '_HOSTS_'
          }
], "no flags");


$parser = App::Clone::Parser::_parser();
$App::Clone::Parser::OPTIONS = { 'skip_lookups' => 1 };
$result = $parser->parse(q|
    _HOSTS_ = {
          ad-dbdev-uwtc-21/r [debian8 @baz.example.com] = {
       # missing }
    }
|);
ok(!defined($result), "mismatched braces");


$parser = App::Clone::Parser::_parser();
$App::Clone::Parser::OPTIONS = { 'skip_lookups' => 1 };
$result = $parser->parse(q|
    _HOSTS_={ad-dbdev-uwtc-21/r[debian8@baz.example.com]=$NETDB_LNX5-64_NS_PROD}
|);
is_deeply($result, [
          {
            'values' => [
                         {
                           'fqdn' => 'baz.example.com',
                           'platform' => 'debian8',
                           'sources' => [
                                          {
                                            'variable' => '$NETDB_LNX5-64_NS_PROD'
                                          }
                                        ],
                           'flags' => 'r',
                           'hostname' => 'ad-dbdev-uwtc-21',
                           'port' => 22,
                         }
                       ],
            'key' => '_HOSTS_'
          }

], "maximally packed syntax");


$parser = App::Clone::Parser::_parser();
$App::Clone::Parser::OPTIONS = { 'skip_lookups' => 1 };
$result = $parser->parse(q|
    _HOSTS_ = {
        aca-test1/ [debian8 @bat.example.com] = $ACATEST_RHEL6_NS
    }
|);
is_deeply($result, [
          {
            'values' => [
                         {
                           'fqdn' => 'bat.example.com',
                           'platform' => 'debian8',
                           'sources' => [
                                          {
                                            'variable' => '$ACATEST_RHEL6_NS'
                                          }
                                        ],
                           'flags' => '',
                           'hostname' => 'aca-test1',
                           'port' => 22,
                         }
                       ],
            'key' => '_HOSTS_'
          }
], "missing flags");


$parser = App::Clone::Parser::_parser();
$App::Clone::Parser::OPTIONS = { 'skip_lookups' => 1 };
$result = $parser->parse(q|
    _HOSTS_ = {
        aca-test1/rxyz [debian8 @bat.example.com] = $ACATEST_RHEL6_NS
    }
|);
ok(!defined($result), "invalid flags");

$parser = App::Clone::Parser::_parser();
$App::Clone::Parser::OPTIONS = { 'skip_lookups' => 1 };
$result = $parser->parse(q|
    _HOSTS_ = {
        aca-test1/r [debian8 @foo.example.com:722] = $ACATEST_RHEL6_NS
    }
|);
is_deeply($result, [
          {
            'values' => [
                         {
                           'fqdn' => 'foo.example.com',
                           'platform' => 'debian8',
                           'sources' => [
                                          {
                                            'variable' => '$ACATEST_RHEL6_NS'
                                          }
                                        ],
                           'flags' => 'r',
                           'hostname' => 'aca-test1',
                           'port' => 722,
                         }
                       ],
            'key' => '_HOSTS_'
          }
], "port number");

done_testing();
