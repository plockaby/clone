#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';

use Test::More;

use_ok("App::Clone::Parser") or BAIL_OUT("cannot test App::Clone::Parser as it is not compiling correctly");

my $result = undef;

$result = App::Clone::Parser->new("");
ok(!defined($result));


$result = App::Clone::Parser->new(q|
    FOO = asdf/fdsa
|);
is_deeply($result, bless({
    '_paths' => {
        'FOO' => [
            ['asdf/fdsa', []]
        ]
    },
    '_hosts' => {},
    '_path_names' => {
        'FOO' => 1,
    },
    '_used_path_names' => {},
    '_options' => {},
}, 'App::Clone::Parser'));


$result = App::Clone::Parser->new(q|
    FOO = {
        asdf/fdsa
    }
|);
is_deeply($result, bless({
    '_paths' => {
        'FOO' => [
            ['asdf/fdsa', []]
        ]
    },
    '_hosts' => {},
    '_path_names' => {
        'FOO' => 1,
    },
    '_used_path_names' => {},
    '_options' => {},
}, 'App::Clone::Parser'));


$result = App::Clone::Parser->new(q|
    FOO (bar) = {
        asdf/fdsa
    }
|);
is_deeply($result, bless({
    '_paths' => {
        'FOO' => [
            ['asdf/fdsa', ['bar']]
        ]
    },
    '_hosts' => {},
    '_path_names' => {
        'FOO' => 1,
    },
    '_used_path_names' => {},
    '_options' => {},
}, 'App::Clone::Parser'));


$result = App::Clone::Parser->new(q|
    FOO (bar) = {
        asdf/
    }
|);
is_deeply($result, bless({
    '_paths' => {
        'FOO' => [
            ['asdf/', ['bar']]
        ]
    },
    '_hosts' => {},
    '_path_names' => {
        'FOO' => 1,
    },
    '_used_path_names' => {},
    '_options' => {},
}, 'App::Clone::Parser'));


$result = App::Clone::Parser->new(q|
    FOO (bar) = {
        asdf/
        asdf/fdsa
    }
|);
is_deeply($result, bless({
    '_paths' => {
        'FOO' => [
            ['asdf/', ['bar']],
            ['asdf/fdsa', ['bar']],
        ]
    },
    '_hosts' => {},
    '_path_names' => {
        'FOO' => 1,
    },
    '_used_path_names' => {},
    '_options' => {},
}, 'App::Clone::Parser'));


$result = App::Clone::Parser->new(q|
    QWERTY = qwerty/ytrewq
    FOO (bar) = {
        asdf/
        asdf/fdsa
        $QWERTY
    }
|);
is_deeply($result, bless({
    '_paths' => {
        'QWERTY' => [
            ['qwerty/ytrewq', []]
        ],
        'FOO' => [
            ['asdf/', ['bar']],
            ['asdf/fdsa', ['bar']],
            ['$QWERTY', ['bar']],
        ],
    },
    '_hosts' => {},
    '_path_names' => {
        'FOO' => 1,
        'QWERTY' => 1,
    },
    '_used_path_names' => {},
    '_options' => {},
}, 'App::Clone::Parser'));


$result = App::Clone::Parser->new(q|
    FOO (bar) = {
        SUBFOO = {
            asdf/fdsa
        }
    }
|);
is_deeply($result, bless({
    '_paths' => {
        'FOO' => [],
        'SUBFOO' => [
            ['asdf/fdsa', ['bar']]
        ]
    },
    '_hosts' => {},
    '_path_names' => {
        'FOO' => 1,
        'SUBFOO' => 1,
    },
    '_used_path_names' => {
        'FOO' => 1,
    },
    '_options' => {},
}, 'App::Clone::Parser'));


$result = App::Clone::Parser->new(q|
    FOO = asdf/
|);
is_deeply($result, bless({
    '_paths' => {
        'FOO' => [
            ['asdf/', []]
        ]
    },
    '_hosts' => {},
    '_path_names' => {
        'FOO' => 1,
    },
    '_used_path_names' => {},
    '_options' => {},
}, 'App::Clone::Parser'));


$result = App::Clone::Parser->new(q|
    FOO = {
        asdf/
    }
|);
is_deeply($result, bless({
    '_paths' => {
        'FOO' => [
            ['asdf/', []]
        ]
    },
    '_hosts' => {},
    '_path_names' => {
        'FOO' => 1,
    },
    '_used_path_names' => {},
    '_options' => {},
}, 'App::Clone::Parser'));


$result = App::Clone::Parser->new(q|
    FOO (bar) = {
        SUBFOO = {
            asdf/
        }
    }
|);
is_deeply($result, bless({
    '_paths' => {
        'FOO' => [],
        'SUBFOO' => [
            ['asdf/', ['bar']]
        ],
    },
    '_hosts' => {},
    '_path_names' => {
        'FOO' => 1,
        'SUBFOO' => 1,
    },
    '_used_path_names' => {
        'FOO' => 1,
    },
    '_options' => {},
}, 'App::Clone::Parser'));


$result = App::Clone::Parser->new(q|
    FOO = asdf
|);
ok(!defined($result));


$result = App::Clone::Parser->new(q|
    FOO = {
        asdf
    }
|);
ok(!defined($result));


$result = App::Clone::Parser->new(q|
    FOO (bar) = {
        asdf
    }
|);
ok(!defined($result));


$result = App::Clone::Parser->new(q|
    FOO (bar) = {
        SUBFOO = {
            asdf
        }
    }
|);
ok(!defined($result));


$result = App::Clone::Parser->new(q|
    ACTIVEMQ = {
        ACTIVEMQ322 (activemq3.2.2) = {
            common/
            ACTIVEMQ322_LNX5 = {
                linux5/
            }
            ACTIVEMQ322_LNX5-64 = {
                linux5_64/
            }
        }
        ACTIVEMQ345 (activemq3.4.5) = {
            common/
            ACTIVEMQ345_RHEL6 = {
                rhel6/
            }
        }
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
            ['linux5/', ['activemq3.2.2']],
        ],
        'ACTIVEMQ322_LNX5-64' => [
            ['common/', ['activemq3.2.2']],
            ['linux5_64/', ['activemq3.2.2']],
        ],
        'ACTIVEMQ345' => [
            ['common/', ['activemq3.4.5']],
        ],
        'ACTIVEMQ345_RHEL6' => [
            ['common/', ['activemq3.4.5']],
            ['rhel6/', ['activemq3.4.5']],
        ],
    },
    '_hosts' => {},
    '_path_names' => {
        'ACTIVEMQ' => 1,
        'ACTIVEMQ322' => 1,
        'ACTIVEMQ322_LNX5' => 1,
        'ACTIVEMQ322_LNX5-64' => 1,
        'ACTIVEMQ345' => 1,
        'ACTIVEMQ345_RHEL6' => 1,
    },
    '_used_path_names' => {
        'ACTIVEMQ' => 1,
        'ACTIVEMQ322' => 1,
        'ACTIVEMQ345' => 1,
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
    '_hosts' => {},
    '_path_names' => {
        'ACTIVEMQ' => 1,
        'ACTIVEMQ322' => 1,
        'ACTIVEMQ322_LNX5' => 1,
        'ACTIVEMQ322_LNX5-64' => 1,
        'ACTIVEMQ345' => 1,
        'ACTIVEMQ345_RHEL6' => 1,
    },
    '_used_path_names' => {
        'ACTIVEMQ' => 1,
        'ACTIVEMQ322' => 1,
        'ACTIVEMQ345' => 1,
    },
    '_options' => {},
}, 'App::Clone::Parser'));


$result = App::Clone::Parser->new(q|
    ALPINE2_COMMON (alpine2) = {
        common/
        ALPINE2_LNX3     = linux3/
        ALPINE2_LNX5     = linux5/
        ALPINE2_LNX5-64  = linux5_64/
        ALPINE2_RHEL6    = rhel6/
    }
|);
is_deeply($result, bless({
    '_paths' => {
        'ALPINE2_COMMON' => [
            ['common/', ['alpine2']]
        ],
        'ALPINE2_LNX3' => [
            ['common/', ['alpine2']],
            ['linux3/', ['alpine2']],
        ],
        'ALPINE2_LNX5' => [
            ['common/', ['alpine2']],
            ['linux5/', ['alpine2']],
        ],
        'ALPINE2_LNX5-64' => [
            ['common/', ['alpine2']],
            ['linux5_64/', ['alpine2']],
        ],
        'ALPINE2_RHEL6' => [
            ['common/', ['alpine2']],
            ['rhel6/', ['alpine2']],
        ],
    },
    '_hosts' => {},
    '_path_names' => {
        'ALPINE2_COMMON' => 1,
        'ALPINE2_LNX3' => 1,
        'ALPINE2_LNX5' => 1,
        'ALPINE2_LNX5-64' => 1,
        'ALPINE2_RHEL6' => 1,
    },
    '_used_path_names' => {
        'ALPINE2_COMMON' => 1,
    },
    '_options' => {},
}, 'App::Clone::Parser'));


$result = App::Clone::Parser->new(q|
    BAR = asdf/fdsa
    FOO = $BAR
|);
is_deeply($result, bless({
    '_paths' => {
        'BAR' => [
            ['asdf/fdsa', []]
        ],
        'FOO' => [
            ['$BAR', []]
        ],
    },
    '_hosts' => {},
    '_path_names' => {
        'FOO' => 1,
        'BAR' => 1,
    },
    '_used_path_names' => {},
    '_options' => {},
}, 'App::Clone::Parser'));


$result = App::Clone::Parser->new(q|
    FOO (bar) = asdf/
|);
is_deeply($result, bless({
    '_paths' => {
        'FOO' => [
            ['asdf/', ['bar']]
        ]
    },
    '_hosts' => {},
    '_path_names' => {
        'FOO' => 1,
    },
    '_used_path_names' => {},
    '_options' => {},
}, 'App::Clone::Parser'));


$result = App::Clone::Parser->new(q|
    FOO (bar) = asdf/fdsa
|);
is_deeply($result, bless({
    '_paths' => {
        'FOO' => [
            ['asdf/fdsa', ['bar']]
        ]
    },
    '_hosts' => {},
    '_path_names' => {
        'FOO' => 1,
    },
    '_used_path_names' => {},
    '_options' => {},
}, 'App::Clone::Parser'));


$result = App::Clone::Parser->new(q|
    ASDF = fdsa/
    FOO (bar) = $ASDF
|);
is_deeply($result, bless({
    '_paths' => {
        'ASDF' => [
            ['fdsa/', []]
        ],
        'FOO' => [
            ['$ASDF', ['bar']]
        ],
    },
    '_hosts' => {},
    '_path_names' => {
        'FOO' => 1,
        'ASDF' => 1,
    },
    '_used_path_names' => {},
    '_options' => {},
}, 'App::Clone::Parser'));


$result = App::Clone::Parser->new(q|
    FOO (asdf fdsa) = {
        baz/bat
        baz/
    }
|);
is_deeply($result, bless({
    '_paths' => {
        'FOO' => [
            ['baz/bat', ['asdf','fdsa']],
            ['baz/', ['asdf','fdsa']],
        ]
    },
    '_hosts' => {},
    '_path_names' => {
        'FOO' => 1,
    },
    '_used_path_names' => {},
    '_options' => {},
}, 'App::Clone::Parser'));


$result = App::Clone::Parser->new(q|
    (asdf fdsa) = {
        common/local
        foo/
        bar/
    }
|);
is_deeply($result, bless({
    '_paths' => {
        '' => [
            ['common/local', ['asdf','fdsa']],
            ['foo/', ['asdf','fdsa']],
            ['bar/', ['asdf','fdsa']],
        ]
    },
    '_hosts' => {},
    '_path_names' => {
        '' => 1,
    },
    '_used_path_names' => {},
    '_options' => {},
}, 'App::Clone::Parser'));


$result = App::Clone::Parser->new(q|
    FOO = { }
|);
is_deeply($result, bless({
    '_paths' => {
        'FOO' => [],
    },
    '_hosts' => {},
    '_path_names' => {
        'FOO' => 1,
    },
    '_used_path_names' => {},
    '_options' => {},
}, 'App::Clone::Parser'));


$result = App::Clone::Parser->new(q|
    FOO (bar) = { }
|);
is_deeply($result, bless({
    '_paths' => {
        'FOO' => [],
    },
    '_hosts' => {},
    '_path_names' => {
        'FOO' => 1,
    },
    '_used_path_names' => {},
    '_options' => {},
}, 'App::Clone::Parser'));


$result = App::Clone::Parser->new(q|# this one begins with comments
    FOO = bar
|);
ok(!defined($result));


$result = App::Clone::Parser->new(q|
    FOO = bar
    # ASDF = fdsa
|);
ok(!defined($result));


$result = App::Clone::Parser->new(q|
    KSPLICE_UPTRACK_BASE (ksplice-common) = {
        linuxcommon/
        KSPLICE_UPTRACK-1.2.2-RHEL6 (ksplice-uptrack-1.2.2) = {
            linuxcommon/
            rhel6/
        }
        KSPLICE_UPTRACK-1.2.12-RHEL6 (ksplice-uptrack-1.2.12) = {
            rhel6/
        }
    }
|);
is_deeply($result, bless({
    '_paths' => {
        'KSPLICE_UPTRACK_BASE' => [
            ['linuxcommon/', ['ksplice-common']]
        ],
        'KSPLICE_UPTRACK-1.2.2-RHEL6' => [
            ['linuxcommon/', ['ksplice-common']],
            ['linuxcommon/', ['ksplice-common','ksplice-uptrack-1.2.2']],
            ['rhel6/', ['ksplice-common','ksplice-uptrack-1.2.2']],
        ],
        'KSPLICE_UPTRACK-1.2.12-RHEL6' => [
            ['linuxcommon/', ['ksplice-common']],
            ['rhel6/', ['ksplice-common','ksplice-uptrack-1.2.12']],
        ],
    },
    '_hosts' => {},
    '_path_names' => {
        'KSPLICE_UPTRACK_BASE' => 1,
        'KSPLICE_UPTRACK-1.2.2-RHEL6' => 1,
        'KSPLICE_UPTRACK-1.2.12-RHEL6' => 1,
    },
    '_used_path_names' => {
        'KSPLICE_UPTRACK_BASE' => 1,
    },
    '_options' => {},
}, 'App::Clone::Parser'));


$result = App::Clone::Parser->new(q|
    NETDB_LNX5-64_NS (netdb_ns) = {
        common/
        linux5_64/
        NETDB_LNX5-64_NS_PROD (netdb_prod_ns) = {
            linux5_64/foo
        }
    }
|);
is_deeply($result, bless({
    '_paths' => {
        'NETDB_LNX5-64_NS' => [
            ['common/', ['netdb_ns']],
            ['linux5_64/', ['netdb_ns']],
        ],
        'NETDB_LNX5-64_NS_PROD' => [
            ['common/', ['netdb_ns']],
            ['linux5_64/', ['netdb_ns']],
            ['linux5_64/foo', ['netdb_ns','netdb_prod_ns']],
        ],
    },
    '_hosts' => {},
    '_path_names' => {
        'NETDB_LNX5-64_NS' => 1,
        'NETDB_LNX5-64_NS_PROD' => 1,
    },
    '_used_path_names' => {
        'NETDB_LNX5-64_NS' => 1,
    },
    '_options' => {},
}, 'App::Clone::Parser'));

done_testing();
