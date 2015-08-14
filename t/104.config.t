#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';

use Try::Tiny;
use Storable qw(lock_retrieve);
use Test::More;

use_ok("App::Clone::Config") or BAIL_OUT("cannot test App::Clone::Config as it is not compiling correctly");

## test that we can write a compiled version and that it matches
try {
    # remove any compiled hosts file
    unlink('t/basics/conf/hosts.compiled');
    ok(!(-e 't/basics/conf/hosts.compiled'), "compiled hosts file removed");

    # try to generate a compiled configuration file
    my $hosts = App::Clone::Config->load('t/basics/conf/hosts', { 'skip_lookups' => 1, 'quiet' => 1 });
    ok($hosts, "load hosts");

    # see if it wrote the hosts.compiled file
    ok(-e 't/basics/conf/hosts.compiled', "compiled hosts file written");

    # now compare the compiled version with what we expect to have
    my $saved = lock_retrieve('t/basics/conf/hosts.compiled');
    is_deeply($hosts, $saved);
} catch {
    my $error = (defined($_) ? $_ : "unknown error");
    fail("write and match compiled hosts file: ${error}");
};

try {
    # remove any compiled hosts file
    unlink('t/basics/conf/hosts.compiled');
    ok(!(-e 't/basics/conf/hosts.compiled'), "compiled hosts file removed");

    # now create a compiled hosts file
    App::Clone::Config->load('t/basics/conf/hosts', { 'skip_lookups' => 1, 'quiet' => 1 });

    # now update the timestamp on the compiled version to be really old and see if it regenerates
    my $now = time();
    utime($now, $now, 't/basics/conf/hosts');
    utime($now - 86400, $now - 86400, 't/basics/conf/hosts.compiled');
    cmp_ok((stat 't/basics/conf/hosts')[9], '>', (stat 't/basics/conf/hosts.compiled')[9]);

    # try to generate a compiled configuration file
    my $hosts = App::Clone::Config->load('t/basics/conf/hosts', { 'skip_lookups' => 1, 'quiet' => 1 });
    ok($hosts, "load hosts again");

    # see if it wrote the hosts.compiled file
    ok(-e 't/basics/conf/hosts.compiled', "compiled hosts file written");

    # the timestamp on the compiled version should now be greater than or equal to the source
    cmp_ok((stat 't/basics/conf/hosts')[9], '<=', (stat 't/basics/conf/hosts.compiled')[9]);

    # now compare the compiled version with what we expect to have
    my $saved = lock_retrieve('t/basics/conf/hosts.compiled');
    is_deeply($hosts, $saved);
} catch {
    my $error = (defined($_) ? $_ : "unknown error");
    fail("regenerate compiled hosts file: ${error}");
};


## create a host file in test mode so that it doesn't save
try {
    # remove any compiled hosts file
    unlink('t/basics/conf/hosts.compiled');
    ok(!(-e 't/basics/conf/hosts.compiled'), "compiled hosts file removed");

    # now create a compiled hosts file but in test mode
    App::Clone::Config->load('t/basics/conf/hosts', { 'test' => 1, 'skip_lookups' => 1, 'quiet' => 1 });

    # make sure it didn't write a compiled version
    ok(!(-e 't/basics/conf/hosts.compiled'), "compiled hosts file removed");
} catch {
    my $error = (defined($_) ? $_ : "unknown error");
    fail("host file in test mode failure: ${error}");
};


## test that we can't write the compiled version
try {
    # remove any compiled hosts file
    unlink('t/basics/conf/hosts.compiled');
    ok(!(-e 't/basics/conf/hosts.compiled'), "compiled hosts file removed");

    try {
        umask(0);
        chmod(oct(555), 't/basics/conf');
        pass("compiled hosts file not writable, could not change perms");
    } catch {
        my $error = (defined($_) ? $_ : "unknown error");
        fail("compiled hosts file not writable, could not change perms: ${error}");
    };

    # now create a compiled hosts file
    App::Clone::Config->load('t/basics/conf/hosts', { 'skip_lookups' => 1, 'quiet' => 1 });

    fail("compiled hosts file not writable");
} catch {
    pass("compiled hosts file not writable");
} finally {
    umask(0);
    chmod(oct(755), 't/basics/conf');
};


## test can't read the compiled version
try {
    # remove any compiled hosts file
    unlink('t/basics/conf/hosts.compiled');
    ok(!(-e 't/basics/conf/hosts.compiled'), "compiled hosts file removed");

    # create a compiled hsots file
    # now create a compiled hosts file
    App::Clone::Config->load('t/basics/conf/hosts', { 'skip_lookups' => 1, 'quiet' => 1 });
    ok(-e 't/basics/conf/hosts.compiled', "compiled hosts file created");

    try {
        umask(0);
        chmod(oct(000), 't/basics/conf/hosts.compiled');
        pass("compiled hosts file not readable, could not change perms");
    } catch {
        my $error = (defined($_) ? $_ : "unknown error");
        fail("compiled hosts file not readable, could not change perms: ${error}");
    };

    # now create a compiled hosts file
    App::Clone::Config->load('t/basics/conf/hosts', { 'skip_lookups' => 1, 'quiet' => 1 });

    fail("compiled hosts file not readable");
} catch {
    pass("compiled hosts file not readable");
} finally {
    umask(0);
    chmod(oct(644), 't/basics/conf/hosts.compiled');
};

done_testing();
