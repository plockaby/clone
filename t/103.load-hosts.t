#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';

use Test::More;

use_ok("App::Clone::Parser") or BAIL_OUT("cannot test App::Clone::Parser as it is not compiling correctly");

my $result = undef;
my $host = undef;

$result = App::Clone::Parser->new(q|
    _HOSTS_ = {
        zzz/r [debian8 @localhost] = $FOO
    }
|);
is_deeply($result, bless({
    '_paths' => {},
    '_hosts' => {
        'zzz' => bless({
            '_hostname' => 'zzz',
            '_flags'    => 'r',
            '_fqdn'     => 'localhost',
            '_platform' => 'debian8',
            '_paths'    => [
                'debian8/zzz',
            ],
        }, 'App::Clone::Parser::Host')
    },
    '_path_names' => {
        'zzz' => 1,
    },
    '_used_path_names' => {
        'zzz' => 1,
    },
    '_options' => {},
}, 'App::Clone::Parser'));

subtest "defined host" => sub {
    plan('skip_all' => 'bad value') unless defined($result);

    # see if the parser returned correct things
    is_deeply($result->hostnames(), [ 'zzz' ]);

    # see if we correctly parsed the hosts
    $host = $result->host('zzz');
    is($host->hostname(), 'zzz');
    is($host->flags(), 'r');
    is($host->fqdn(), 'localhost');

    done_testing();
};


$result = App::Clone::Parser->new(q|
    FOO = asdf/fdsa

    _HOSTS_ = {
        zzz/r [debian8 @localhost] = $FOO
    }
|);
is_deeply($result, bless({
    '_paths' => {
        'FOO' => [
            ['asdf/fdsa', []]
        ]
    },
    '_hosts' => {
        'zzz' => bless({
            '_hostname' => 'zzz',
            '_flags'    => 'r',
            '_fqdn'     => 'localhost',
            '_platform' => 'debian8',
            '_paths'    => [
                'asdf/fdsa',
                'debian8/zzz',
            ],
        }, 'App::Clone::Parser::Host')
    },
    '_path_names' => {
        'zzz' => 1,
        'FOO' => 1,
    },
    '_used_path_names' => {
        'zzz' => 1,
        'FOO' => 1,
    },
    '_options' => {},
}, 'App::Clone::Parser'));

subtest "defined host" => sub {
    plan('skip_all' => 'bad value') unless defined($result);

    # see if the parser returned correct things
    is_deeply($result->hostnames(), [ 'zzz' ]);

    # see if we correctly parsed the host
    $host = $result->host('zzz');
    is($host->hostname(), 'zzz');
    is($host->flags(), 'r');
    is($host->fqdn(), 'localhost');
    is_deeply($host->paths(), [
        'asdf/fdsa',
        'debian8/zzz',
    ]);

    done_testing();
};


$result = App::Clone::Parser->new(q|
    _HOSTS_ = {
        zzz/r [debian8 @localhost] = {
            asdf/fdsa
        }
    }
|);
is_deeply($result, bless({
    '_paths' => {},
    '_hosts' => {
        'zzz' => bless({
            '_hostname' => 'zzz',
            '_flags'    => 'r',
            '_fqdn'     => 'localhost',
            '_platform' => 'debian8',
            '_paths'    => [
                'asdf/fdsa',
                'debian8/zzz',
            ],
        }, 'App::Clone::Parser::Host')
    },
    '_path_names' => {
        'zzz' => 1,
    },
    '_used_path_names' => {
        'zzz' => 1,
    },
    '_options' => {},
}, 'App::Clone::Parser'));

subtest "defined host" => sub {
    plan('skip_all' => 'bad value') unless defined($result);

    # see if the parser returned correct things
    is_deeply($result->hostnames(), [ 'zzz' ]);

    done_testing();
};


$result = App::Clone::Parser->new(q|
    FOO = {
        asdf/fdsa
    }

    _HOSTS_ = {
        zzz/r [debian8 @localhost] = $FOO
    }
|);
is_deeply($result, bless({
    '_paths' => {
        'FOO' => [
            ['asdf/fdsa', []]
        ]
    },
    '_hosts' => {
        'zzz' => bless({
            '_hostname' => 'zzz',
            '_flags'    => 'r',
            '_fqdn'     => 'localhost',
            '_platform' => 'debian8',
            '_paths'    => [
                'asdf/fdsa',
                'debian8/zzz',
            ],
        }, 'App::Clone::Parser::Host')
    },
    '_path_names' => {
        'zzz' => 1,
        'FOO' => 1,
    },
    '_used_path_names' => {
        'zzz' => 1,
        'FOO' => 1,
    },
    '_options' => {},
}, 'App::Clone::Parser'));


$result = App::Clone::Parser->new(q|
    FOO = {
        asdf/fdsa
        $BAR
    }

    BAR = {
        baz/bat
    }

    _HOSTS_ = {
        zzz/r [debian8 @localhost] = $FOO
    }
|);
is_deeply($result, bless({
    '_paths' => {
        'FOO' => [
            ['asdf/fdsa', []],
            ['$BAR', []],
        ],
        'BAR' => [
            ['baz/bat', []]
        ],
    },
    '_hosts' => {
        'zzz' => bless({
            '_hostname' => 'zzz',
            '_flags'    => 'r',
            '_fqdn'     => 'localhost',
            '_platform' => 'debian8',
            '_paths'    => [
                'asdf/fdsa',
                'baz/bat',
                'debian8/zzz',
            ],
        }, 'App::Clone::Parser::Host')
    },
    '_path_names' => {
        'FOO' => 1,
        'BAR' => 1,
        'zzz' => 1,
    },
    '_used_path_names' => {
        'FOO' => 1,
        'BAR' => 1,
        'zzz' => 1,
    },
    '_options' => {},
}, 'App::Clone::Parser'));


$result = App::Clone::Parser->new(q|
    FOO = {
        asdf/fdsa
        $BAR
    }

    BAR = {
        baz/bat
        $BAZ
    }

    BAZ = {
        qwerty/ytrewq
    }

    _HOSTS_ = {
        zzz/r [debian8 @localhost] = $FOO
    }
|);
is_deeply($result, bless({
    '_paths' => {
        'FOO' => [
            ['asdf/fdsa', []],
            ['$BAR', []],
        ],
        'BAR' => [
            ['baz/bat', []],
            ['$BAZ', []],
        ],
        'BAZ' => [
            ['qwerty/ytrewq', []],
        ],
    },
    '_hosts' => {
        'zzz' => bless({
            '_hostname' => 'zzz',
            '_flags'    => 'r',
            '_fqdn'     => 'localhost',
            '_platform' => 'debian8',
            '_paths'    => [
                'asdf/fdsa',
                'baz/bat',
                'debian8/zzz',
                'qwerty/ytrewq',
            ],
        }, 'App::Clone::Parser::Host')
    },
    '_path_names' => {
        'FOO' => 1,
        'BAR' => 1,
        'BAZ' => 1,
        'zzz' => 1,
    },
    '_used_path_names' => {
        'FOO' => 1,
        'BAR' => 1,
        'BAZ' => 1,
        'zzz' => 1,
    },
    '_options' => {},
}, 'App::Clone::Parser'));


$result = App::Clone::Parser->new(q|
    FOO (bar) = {
        asdf/
        asdf/fdsa
    }

    _HOSTS_ = {
        zzz/r [debian8 @localhost] = $FOO
    }
|);
is_deeply($result, bless({
    '_paths' => {
        'FOO' => [
            ['asdf/', ['bar']],
            ['asdf/fdsa', ['bar']],
        ]
    },
    '_hosts' => {
        'zzz' => bless({
            '_hostname' => 'zzz',
            '_flags'    => 'r',
            '_fqdn'     => 'localhost',
            '_platform' => 'debian8',
            '_paths'    => [
                'asdf/bar',
                'asdf/fdsa',
                'debian8/zzz',
            ],
        }, 'App::Clone::Parser::Host')
    },
    '_path_names' => {
        'FOO' => 1,
        'zzz' => 1,
    },
    '_used_path_names' => {
        'FOO' => 1,
        'zzz' => 1,
    },
    '_options' => {},
}, 'App::Clone::Parser'));


$result = App::Clone::Parser->new(q|
    ACTIVEMQ = {
        ACTIVEMQ322 (activemq3.2.2) = {
            common/
            ACTIVEMQ322_LNX5 (foo) = {
                linux5/
            }
            ACTIVEMQ322_LNX5-64 (bar) = {
                linux5_64/
            }
        }
        ACTIVEMQ345 (activemq3.4.5) = {
            common/
            ACTIVEMQ345_RHEL6 (baz) = {
                rhel6/
            }
        }
    }

    _HOSTS_ = {
        zzz/r [debian8 @localhost] = $ACTIVEMQ345_RHEL6
    }
|);
is_deeply($result, bless({
    '_paths' => {
        'ACTIVEMQ' => [],
        'ACTIVEMQ322' => [
            ['common/', ['activemq3.2.2']],
        ],
        'ACTIVEMQ322_LNX5' => [
            ['common/', ['activemq3.2.2']],
            ['linux5/', ['activemq3.2.2','foo']],
        ],
        'ACTIVEMQ322_LNX5-64' => [
            ['common/', ['activemq3.2.2']],
            ['linux5_64/', ['activemq3.2.2','bar']],
        ],
        'ACTIVEMQ345' => [
            ['common/', ['activemq3.4.5']],
        ],
        'ACTIVEMQ345_RHEL6' => [
            ['common/', ['activemq3.4.5']],
            ['rhel6/', ['activemq3.4.5','baz']],
        ],
    },
    '_hosts' => {
        'zzz' => bless({
            '_hostname' => 'zzz',
            '_flags'    => 'r',
            '_fqdn'     => 'localhost',
            '_platform' => 'debian8',
            '_paths'    => [
                'common/activemq3.4.5',
                'debian8/zzz',
                'rhel6/activemq3.4.5',
                'rhel6/baz',
            ],
        }, 'App::Clone::Parser::Host')
    },
    '_path_names' => {
        'ACTIVEMQ' => 1,
        'ACTIVEMQ322' => 1,
        'ACTIVEMQ322_LNX5' => 1,
        'ACTIVEMQ322_LNX5-64' => 1,
        'ACTIVEMQ345' => 1,
        'ACTIVEMQ345_RHEL6' => 1,
        'zzz' => 1,
    },
    '_used_path_names' => {
        'ACTIVEMQ' => 1,
        'ACTIVEMQ322' => 1,
        'ACTIVEMQ345' => 1,
        'ACTIVEMQ345_RHEL6' => 1,
        'zzz' => 1,
    },
    '_options' => {},
}, 'App::Clone::Parser'));


$result = App::Clone::Parser->new(q|
    (os local) = {
        LNX5_BASE = {
            linux5/
            linuxcommon/
        }
        RHEL6_BASE = {
            rhel6/
            linuxcommon/
        }
    }

    FOO = {
        asdf/fdsa
        $RHEL6_BASE
    }

    _HOSTS_ = {
        zzz/r [debian8 @localhost] = $FOO
    }
|);
is_deeply($result, bless({
    '_paths' => {
        '' => [],
        'LNX5_BASE' => [
            ['linux5/', ['os','local']],
            ['linuxcommon/', ['os','local']],
        ],
        'RHEL6_BASE' => [
            ['rhel6/', ['os','local']],
            ['linuxcommon/', ['os','local']],
        ],
        'FOO' => [
            ['asdf/fdsa', []],
            ['$RHEL6_BASE', []],
        ],
    },
    '_hosts' => {
        'zzz' => bless({
            '_hostname' => 'zzz',
            '_flags'    => 'r',
            '_fqdn'     => 'localhost',
            '_platform' => 'debian8',
            '_paths'    => [
                'asdf/fdsa',
                'debian8/zzz',
                'linuxcommon/local',
                'linuxcommon/os',
                'rhel6/local',
                'rhel6/os',
            ],
        }, 'App::Clone::Parser::Host')
    },
    '_path_names' => {
        '' => 1,
        'LNX5_BASE' => 1,
        'RHEL6_BASE' => 1,
        'FOO' => 1,
        'zzz' => 1,
    },
    '_used_path_names' => {
        '' => 1,
        'FOO' => 1,
        'RHEL6_BASE' => 1,
        'zzz' => 1,
    },
    '_options' => {},
}, 'App::Clone::Parser'));

done_testing();
