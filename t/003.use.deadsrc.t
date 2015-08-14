#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';

use Test::More;
use Try::Tiny;
use Cwd ();

require_ok("./bin/deadsrc") or BAIL_OUT("cannot test deadsrc as it is not compiling correctly");

my $current_path = Cwd::cwd();

## hosts file does not exist
try {
    main('hosts' => 't/basics/conf/hosts-does-not-exist', 'config' => 't/basics/conf/config.ini', 'quiet' => 1, 'skip_lookups' => 1);
    fail("missing hosts file");
} catch {
    pass("missing hosts file");
};

## config.ini does not exist
try {
    main('hosts' => 't/basics/conf/hosts', 'config' => 't/basics/conf/config.ini-does-not-exist', 'quiet' => 1, 'skip_lookups' => 1);
    fail("missing config.ini file");
} catch {
    pass("missing config.ini file");
};

## hosts file is invalid
try {
    main('hosts' => 't/basics/conf/hosts-invalid', 'config' => 't/basics/conf/config.ini', 'quiet' => 1, 'skip_lookups' => 1);
    fail("invalid hosts file");
} catch {
    pass("invalid hosts file");
};

## config file is not readable
try {
    try {
        umask(0);
        chmod(oct(000), 't/basics/conf/config.ini-not-readable');
        pass("unreadable config.ini file, change permissions");
    } catch {
        my $error = (defined($_) ? $_ : "unknown error");
        fail("unreadable config.ini file, could not change permissions: ${error}");
    };
    main('hosts' => 't/basics/conf/hosts', 'config' => 't/basics/conf/config.ini-not-readable', 'quiet' => 1, 'skip_lookups' => 1);
    fail("unreadable config.ini file");
} catch {
    pass("unreadable config.ini file");
} finally {
    umask(0);
    chmod(oct(644), 't/basics/conf/config.ini-not-readable');
};

subtest "deadsrc" => sub {
    try {
        require Test::Output;
    } catch {
        plan('skip_all' => 'Test::Output not found.');
    };

    Test::Output::combined_is(sub {
        main('hosts' => 't/basics/conf/hosts', 'config' => 't/basics/conf/config.ini', 'quiet' => 1, 'skip_lookups' => 1),
    }, "${current_path}/t/basics/sources/test/baz\n", undef, 'test1');

    Test::Output::combined_is(sub {
        main('hosts' => 't/basics/conf/hosts', 'config' => 't/basics/conf/config.ini', 'quiet' => 0, 'skip_lookups' => 1),
    }, "These these source trees are on the filesystem but not used by any hosts:\n" .
       " - ${current_path}/t/basics/sources/test/baz\n", undef, 'test1');

    done_testing();
};

done_testing();
