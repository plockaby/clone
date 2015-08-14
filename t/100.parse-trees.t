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
$result = $parser->parse("");
ok(!defined($result), "empty config");


$parser = App::Clone::Parser::_parser();
$result = $parser->parse(q|
    FOO = asdf/fdsa
|);
is_deeply($result, [
          {
            'suffixes' => [],
            'values' => [
                          {
                            'path' => 'asdf/fdsa'
                          }
                        ],
            'key' => 'FOO'
          }
], "variable path assignment");


$parser = App::Clone::Parser::_parser();
$result = $parser->parse(q|
    FOO = asdf/
|);
is_deeply($result, [
          {
            'suffixes' => [],
            'values' => [
                          {
                            'path' => 'asdf/'
                          }
                        ],
            'key' => 'FOO'
          }
], "variable path assignment 2");


$parser = App::Clone::Parser::_parser();
$result = $parser->parse(q|
    FOO = asdf
|);
ok(!defined($result), "variable path assignment 3: bad path no slash");


$parser = App::Clone::Parser::_parser();
$result = $parser->parse(q|
    FOO (bar) = {
        asdf
    }
|);
ok(!defined($result), "variable path assignment 4: bad path but deeper");


$parser = App::Clone::Parser::_parser();
$result = $parser->parse(q|
    FOO (bar) = {
        NESTED = {
           asdf
        }
    }
|);
ok(!defined($result), "variable path assignment 5: bad path double nest");


$parser = App::Clone::Parser::_parser();
$result = $parser->parse(q|
    FOO = $variable_expansion
|);
is_deeply($result, [
          {
            'suffixes' => [],
            'values' => [
                          {
                            'variable' => '$variable_expansion'
                          }
                        ],
            'key' => 'FOO'
          }
], "variable expansion assignment 1");


$parser = App::Clone::Parser::_parser();
$result = $parser->parse(q|
    FOO (x y) = suffixme/
|);
is_deeply($result, [
         {
            'suffixes' => [
                            [
                              'x',
                              'y'
                            ]
                          ],
            'values' => [
                          {
                            'path' => 'suffixme/'
                          }
                        ],
            'key' => 'FOO'
          }
], "single path with suffixes");


$parser = App::Clone::Parser::_parser();
$result = $parser->parse(q|
    FOO = {
        asdf/fdsa
    }
|);
is_deeply($result, [
          {
            'suffixes' => [],
            'values' => [
                         {
                           'path' => 'asdf/fdsa'
                         }
                       ],
            'key' => 'FOO'
          }
], "nested definition");


$parser = App::Clone::Parser::_parser();
$result = $parser->parse(q|
    FOO = {
        asdf/fdsa
        asdf2/fdsa2
        $nvar
        asdf3/fdsa3
        $nvar2
    }
|);
is_deeply($result, [
          {
            'suffixes' => [],
            'values' => [
                         {
                           'path' => 'asdf/fdsa'
                         },
                         {
                           'path' => 'asdf2/fdsa2'
                         },
                         {
                           'variable' => '$nvar'
                         },
                         {
                           'path' => 'asdf3/fdsa3'
                         },
                         {
                           'variable' => '$nvar2'
                         }
                       ],
            'key' => 'FOO'
          }
], "nested definition 2");


$parser = App::Clone::Parser::_parser();
$result = $parser->parse(q|
    # maxiumally packed syntax
    FOO={asdf/fdsa asdf2/fdsa2 $nvar BAR={$THING}asdf3/fdsa3 $nvar2}
|);
is_deeply($result, [
          {
            'suffixes' => [],
            'values' => [
                         {
                           'path' => 'asdf/fdsa'
                         },
                         {
                           'path' => 'asdf2/fdsa2'
                         },
                         {
                           'variable' => '$nvar'
                         },
                         {
                           'suffixes' => [],
                           'values' => [
                                        {
                                          'variable' => '$THING'
                                        }
                                      ],
                           'key' => 'BAR'
                         },
                         {
                           'path' => 'asdf3/fdsa3'
                         },
                         {
                           'variable' => '$nvar2'
                         }
                       ],
            'key' => 'FOO'
          }
], "nested definition 2 max packed");


$parser = App::Clone::Parser::_parser();
$result = $parser->parse(q|
    FOO (bar) = {
        asdf/fdsa
    }
|);
is_deeply($result, [
          {
            'suffixes' => [
                            [
                              'bar'
                            ]
                          ],
            'values' => [
                         {
                           'path' => 'asdf/fdsa'
                         }
                       ],
            'key' => 'FOO'
          }
], "nested defintiion with suffixes 1");


$parser = App::Clone::Parser::_parser();
$result = $parser->parse(q|
    FOO (bar thing yep) = {
        asdf/fdsa
    }
|);
is_deeply($result, [
          {
            'suffixes' => [
                            [
                              'bar',
                              'thing',
                              'yep'
                            ]
                          ],
            'values' => [
                         {
                           'path' => 'asdf/fdsa'
                         }
                       ],
            'key' => 'FOO'
          }
], "nested defintiion with suffixes 2");


$parser = App::Clone::Parser::_parser();
$result = $parser->parse(q|
    FOO (bar) = {
        asdf/
    }
|);
is_deeply($result, [
          {
            'suffixes' => [
                            [
                              'bar'
                            ]
                          ],
            'values' => [
                         {
                           'path' => 'asdf/'
                         }
                       ],
            'key' => 'FOO'
          }
], "nested defintion with suffixes 3");


$parser = App::Clone::Parser::_parser();
$result = $parser->parse(q|
    FOO (bar) = {
        asdf/
        asdf/fdsa
    }
|);
is_deeply($result, [
          {
            'suffixes' => [
                            [
                              'bar'
                            ]
                          ],
            'values' => [
                         {
                           'path' => 'asdf/'
                         },
                         {
                           'path' => 'asdf/fdsa'
                         }
                       ],
            'key' => 'FOO'
          }
], "nested defintion with suffixes 4");


$parser = App::Clone::Parser::_parser();
$result = $parser->parse(q|
    FOO (bar) = {
        asdf/
        asdf/fdsa
        $QWERTY
    }
|);
is_deeply($result, [
          {
            'suffixes' => [
                            [
                              'bar'
                            ]
                          ],
            'values' => [
                         {
                           'path' => 'asdf/'
                         },
                         {
                           'path' => 'asdf/fdsa'
                         },
                         {
                           'variable' => '$QWERTY'
                         }
                       ],
            'key' => 'FOO'
          }
], "nested defintion with suffixes 5");


$parser = App::Clone::Parser::_parser();
$result = $parser->parse(q|
    FOO (bar) = {
        SUBFOO = {
            asdf/fdsa
        }
    }
|);
is_deeply($result, [
          {
            'suffixes' => [
                            [
                              'bar'
                            ]
                          ],
            'values' => [
                         {
                           'suffixes' => [],
                           'values' => [
                                        {
                                          'path' => 'asdf/fdsa'
                                        }
                                      ],
                           'key' => 'SUBFOO'
                         }
                       ],
            'key' => 'FOO'
          }
], "double nested 1");


$parser = App::Clone::Parser::_parser();
$result = $parser->parse(q|
    ACTIVEMQ = {
        ACTIVEMQ322 (activemq3.2.2) = {
            common/
            ACTIVEMQ322_LNX5 = {
                linux5/
                $EZS_131_LNX5
                $APR142_LNX5
                $APRUTIL139_LNX5
            }
            ACTIVEMQ322_LNX5-64 = {
                linux5_64/
                $EZS_131_LNX5-64
                going/to/a/path
                $APR142_LNX5-64
                $APRUTIL139_LNX5-64
            }
        }
        ACTIVEMQ345 (activemq3.4.5) = {
            common/
            ACTIVEMQ345_RHEL6 = {
                rhel6/
                $EZS_131_RHEL6
                # Must include either APACHE or APR/APRUTIL
                ACTIVEMQ345_RHEL6_NEST = $variable_here
            }
        }
    }
|);
is_deeply($result, [
          {
            'suffixes' => [],
            'values' => [
                         {
                           'suffixes' => [
                                           [
                                             'activemq3.2.2'
                                           ]
                                         ],
                           'values' => [
                                        {
                                          'path' => 'common/'
                                        },
                                        {
                                          'suffixes' => [],
                                          'values' => [
                                                       {
                                                         'path' => 'linux5/'
                                                       },
                                                       {
                                                         'variable' => '$EZS_131_LNX5'
                                                       },
                                                       {
                                                         'variable' => '$APR142_LNX5'
                                                       },
                                                       {
                                                         'variable' => '$APRUTIL139_LNX5'
                                                       }
                                                     ],
                                          'key' => 'ACTIVEMQ322_LNX5'
                                        },
                                        {
                                          'suffixes' => [],
                                          'values' => [
                                                       {
                                                         'path' => 'linux5_64/'
                                                       },
                                                       {
                                                         'variable' => '$EZS_131_LNX5-64'
                                                       },
                                                       {
                                                         'path' => 'going/to/a/path'
                                                       },
                                                       {
                                                         'variable' => '$APR142_LNX5-64'
                                                       },
                                                       {
                                                         'variable' => '$APRUTIL139_LNX5-64'
                                                       }
                                                     ],
                                          'key' => 'ACTIVEMQ322_LNX5-64'
                                        }
                                      ],
                           'key' => 'ACTIVEMQ322'
                         },
                         {
                           'suffixes' => [
                                           [
                                             'activemq3.4.5'
                                           ]
                                         ],
                           'values' => [
                                        {
                                          'path' => 'common/'
                                        },
                                        {
                                          'suffixes' => [],
                                          'values' => [
                                                       {
                                                        'path' => 'rhel6/'
                                                       },
                                                       {
                                                         'variable' => '$EZS_131_RHEL6'
                                                       },
                                                       {
                                                         'suffixes' => [],
                                                         'values' => [
                                                                       {
                                                                         'variable' => '$variable_here'
                                                                       }
                                                                     ],
                                                         'key' => 'ACTIVEMQ345_RHEL6_NEST'
                                                       }
                                                     ],
                                          'key' => 'ACTIVEMQ345_RHEL6'
                                        }
                                      ],
                           'key' => 'ACTIVEMQ345'
                         }
                       ],
            'key' => 'ACTIVEMQ'
          }
], "a super complicated nested example with comments");


$parser = App::Clone::Parser::_parser();
$result = $parser->parse(q|
    ACTIVEMQ = {
        ACTIVEMQ322 (activemq3.2.2) = {
            common/
            ACTIVEMQ322_LNX5 = {
                linux5/
                $EZS_131_LNX5
                $APR142_LNX5
                $APRUTIL139_LNX5
            }
            ACTIVEMQ322_LNX5-64 = {
                linux5_64/
                $EZS_131_LNX5-64
                $APR142_LNX5-64
                $APRUTIL139_LNX5-64
            }
        }
        ACTIVEMQ345 (activemq3.4.5) = {
            common/
            ACTIVEMQ345_RHEL6 = {
                rhel6/
                $EZS_131_RHEL6
                # Must include either APACHE or APR/APRUTIL
            }
        }
   # should be close brace here

   ALPINE2_COMMON (alpine2) = {
        common/
        ALPINE2_LNX3     = linux3/
        ALPINE2_LNX5     = linux5/
        ALPINE2_LNX5-64  = linux5_64/
        ALPINE2_RHEL6    = rhel6/
    }
|);
ok(!defined($result), "a super complicated example with a syntax error");


$parser = App::Clone::Parser::_parser();
$result = $parser->parse(q|
    ALPINE2_COMMON (alpine2) = {
        common/
        ALPINE2_LNX3     = linux3/
        ALPINE2_LNX5     = linux5/
        ALPINE2_LNX5-64  = linux5_64/
        ALPINE2_RHEL6    = rhel6/
    }
|);
is_deeply($result, [
          {
            'suffixes' => [
                            [
                              'alpine2'
                            ]
                          ],
            'values' => [
                         {
                           'path' => 'common/'
                         },
                         {
                           'suffixes' => [],
                           'values' => [
                                         {
                                           'path' => 'linux3/'
                                         }
                                       ],
                           'key' => 'ALPINE2_LNX3'
                         },
                         {
                           'suffixes' => [],
                           'values' => [
                                         {
                                           'path' => 'linux5/'
                                         }
                                       ],
                           'key' => 'ALPINE2_LNX5'
                         },
                         {
                           'suffixes' => [],
                           'values' => [
                                         {
                                           'path' => 'linux5_64/'
                                         }
                                       ],
                           'key' => 'ALPINE2_LNX5-64'
                         },
                         {
                           'suffixes' => [],
                           'values' => [
                                         {
                                           'path' => 'rhel6/'
                                         }
                                       ],
                           'key' => 'ALPINE2_RHEL6'
                         }
                       ],
            'key' => 'ALPINE2_COMMON'
          }
], "some other test");


$parser = App::Clone::Parser::_parser();
$result = $parser->parse(q|
    (asdf fdsa) = {
        common/local
        foo/
        bar/
    }
|);
is_deeply($result, [
          {
            'suffixes' => [
                            [
                              'asdf',
                              'fdsa'
                            ]
                          ],
            'values' => [
                         {
                           'path' => 'common/local'
                         },
                         {
                           'path' => 'foo/'
                         },
                         {
                           'path' => 'bar/'
                         }
                       ],
            'key' => ''
          }
], "anonymous defintion");


$parser = App::Clone::Parser::_parser();
$result = $parser->parse(q|
    FOO = { }
|);
is_deeply($result, [
          {
            'suffixes' => [],
            'values' => [],
            'key' => 'FOO'
          }
], "empty block 1");


$parser = App::Clone::Parser::_parser();
$result = $parser->parse(q|
    FOO = {}
|);
is_deeply($result, [
          {
            'suffixes' => [],
            'values' => [],
            'key' => 'FOO'
          }
], "empty block 2");


$parser = App::Clone::Parser::_parser();
$result = $parser->parse(q|
    FOO = {

}
|);
is_deeply($result, [
          {
            'suffixes' => [],
            'values' => [],
            'key' => 'FOO'
          }
], "empty block 3");


$parser = App::Clone::Parser::_parser();
$result = $parser->parse(q|
    FOO = {
   # comment here
   # linux5/
# linux5/
# BAR = $THING
}
|);
is_deeply($result, [
          {
            'suffixes' => [],
            'values' => [],
            'key' => 'FOO'
          }
], "empty block 4 (comments)");


$parser = App::Clone::Parser::_parser();
$result = $parser->parse(q|
    FOO (bar) = { }
|);
is_deeply($result, [
          {
            'suffixes' => [
                            [
                              'bar'
                            ]
                          ],
            'values' => [],
            'key' => 'FOO'
          }
], "empty block with suffixes");


$parser = App::Clone::Parser::_parser();
$result = $parser->parse(q|
    # comments here
    FOO = bar/  #comments here
    # BAR = $foo
|);
is_deeply($result, [
          {
            'suffixes' => [],
            'values' => [
                          {
                            'path' => 'bar/'
                          }
                        ],
            'key' => 'FOO'
          }
], "various comments");


$parser = App::Clone::Parser::_parser();
$result = $parser->parse(q|
    FOO = $$bar
    # too many $
|);
ok(!defined($result), "syntax error 1");


$parser = App::Clone::Parser::_parser();
$result = $parser->parse(q|
    FOO == $bar
    # too many =
|);
ok(!defined($result), "syntax error 2");


$parser = App::Clone::Parser::_parser();
$result = $parser->parse(q|
    $FOO = bar/   # expansion with assignment not allowed
|);
ok(!defined($result), "syntax error 3");


$parser = App::Clone::Parser::_parser();
$result = $parser->parse(q|
    FOO ()= bar/   # no suffixes
|);
ok(!defined($result), "syntax error 3");

done_testing();
