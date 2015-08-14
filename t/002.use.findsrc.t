#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';

use Test::More;
use Try::Tiny;
use Cwd ();

require_ok("./bin/findsrc") or BAIL_OUT("cannot test findsrc as it is not compiling correctly");

my $current_path = Cwd::cwd();

## hosts file is missing
try {
    main('example', '/myfile.txt', 'hosts' => 't/basics/conf/hosts-does-not-exist', 'config' => 't/basics/conf/config.ini', 'quiet' => 1, 'skip_lookups' => 1);
    fail("missing hosts file");
} catch {
    pass("missing hosts file");
};

## config.ini file is missing
try {
    main('example', '/myfile.txt', 'hosts' => 't/basics/conf/hosts', 'config' => 't/basics/conf/config.ini-does-not-exist', 'quiet' => 1, 'skip_lookups' => 1);
    fail("missing config.ini file");
} catch {
    pass("missing config.ini file");
};

## hosts file is invalid
try {
    main('example', '/myfile.txt', 'hosts' => 't/basics/conf/hosts-invalid', 'config' => 't/basics/conf/config.ini', 'quiet' => 1, 'skip_lookups' => 1);
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
    main('example', '/myfile.txt', 'hosts' => 't/basics/conf/hosts', 'config' => 't/basics/conf/config.ini-not-readable', 'quiet' => 1, 'skip_lookups' => 1);
    fail("unreadable config.ini file");
} catch {
    pass("unreadable config.ini file");
} finally {
    umask(0);
    chmod(oct(644), 't/basics/conf/config.ini-not-readable');
};

## hosts file is not readable
try {
    try {
        umask(0);
        chmod(oct(000), 't/basics/conf/hosts-not-readable');
        pass("unreadable hosts file, change permissions");
    } catch {
        my $error = (defined($_) ? $_ : "unknown error");
        fail("unreadable hosts file, could not change permissions: ${error}");
    };
    main('example', '/myfile.txt', 'hosts' => 't/basics/conf/hosts-not-readable', 'config' => 't/basics/conf/config.ini', 'quiet' => 1, 'skip_lookups' => 1);
    fail("unreadable hosts file");
} catch {
    pass("unreadable hosts file");
} finally {
    umask(0);
    chmod(oct(644), 't/basics/conf/hosts-not-readable');
};


## try an invalid hostname
try {
    main('example', '/myfile.txt', 'hosts' => 't/basics/conf/hosts', 'config' => 't/basics/conf/config.ini', 'quiet' => 1, 'skip_lookups' => 1);
    fail("unknown hostname");
} catch {
    pass("unknown hostname");
};

subtest "findsrc" => sub {
    try {
        require Test::Output;
    } catch {
        plan('skip_all' => 'Test::Output not found.');
    };

    Test::Output::combined_is(sub {
        main('example1', '/myfile.txt', 'hosts' => 't/basics/conf/hosts', 'config' => 't/basics/conf/config.ini', 'quiet' => 1, 'skip_lookups' => 1),
    }, "  ${current_path}/t/basics/sources/test/foo/myfile.txt\n", undef, 'test1');

    Test::Output::combined_is(sub {
        main('example1', '/yourfile.txt', 'hosts' => 't/basics/conf/hosts', 'config' => 't/basics/conf/config.ini', 'quiet' => 1, 'skip_lookups' => 1),
    }, "  ${current_path}/t/basics/sources/test/bar/yourfile.txt\n", undef, 'test2');

    Test::Output::combined_is(sub {
        main('example3', '/etc/blarg.txt', 'hosts' => 't/basics/conf/hosts', 'config' => 't/basics/conf/config.ini', 'quiet' => 1, 'skip_lookups' => 1),
    }, "  ${current_path}/t/basics/sources/test/dir1/etc/blarg.txt\n", undef, 'test3');

    done_testing();
};

done_testing();
