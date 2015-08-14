#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';

use Test::More;
use File::Path qw(remove_tree);
use File::Find;
use Try::Tiny;

use_ok("App::Clone::Config") or BAIL_OUT("cannot test App::Clone::Config as it is not compiling correctly");
use_ok("App::Clone::Linker") or BAIL_OUT("cannot test App::Clone::Linker as it is not compiling correctly");


## test build path not defined
try {
    App::Clone::Linker->new({ 'paths' => { 'sources' => 't/linker/sources' } });
    fail("build path not defined");
} catch {
    pass("build path not defined");
};

## test build path not a directory
try {
    App::Clone::Linker->new({ 'paths' => { 'sources' => 't/linker/sources', 'builds' => 't/linker/builds-not-directory' } });
    fail("build path not a directory");
} catch {
    pass("build path not a directory");
};

## test build path not writable (missing writable)
try {
    try {
        umask(0);
        chmod(oct(555), 't/linker/builds-no-perms');
        pass("build path not writable (missing writable), could not change perms");
    } catch {
        my $error = (defined($_) ? $_ : "unknown error");
        fail("build path not writable (missing writable), could not change perms: ${error}");
    };
    App::Clone::Linker->new({ 'paths' => { 'sources' => 't/linker/sources', 'builds' => 't/linker/builds-no-perms' } });
    fail("build path not writable (missing writable)");
} catch {
    pass("build path not writable (missing writable)");
} finally {
    umask(0);
    chmod(oct(755), 't/linker/builds-no-perms');
};


## test build path not writable (missing executable)
try {
    try {
        umask(0);
        chmod(oct(666), 't/linker/builds-no-perms');
        pass("build path not writable (missing writable), could not change perms");
    } catch {
        my $error = (defined($_) ? $_ : "unknown error");
        fail("build path not writable (missing writable), could not change perms: ${error}");
    };
    App::Clone::Linker->new({ 'paths' => { 'sources' => 't/linker/sources', 'builds' => 't/linker/builds-no-perms' } });
    fail("build path not writable (missing writable)");
} catch {
    pass("build path not writable (missing writable)");
} finally {
    umask(0);
    chmod(oct(755), 't/linker/builds-no-perms');
};


## test build path not writable (missing both)
try {
    try {
        umask(0);
        chmod(oct(444), 't/linker/builds-no-perms');
        pass("build path not writable (missing both), could not change perms");
    } catch {
        my $error = (defined($_) ? $_ : "unknown error");
        fail("build path not writable (missing both), could not change perms: ${error}");
    };
    App::Clone::Linker->new({ 'paths' => { 'sources' => 't/linker/sources', 'builds' => 't/linker/builds-no-perms' } });
    fail("build path not writable (missing both)");
} catch {
    pass("build path not writable (missing both)");
} finally {
    umask(0);
    chmod(oct(755), 't/linker/builds-no-perms');
};


## test source path not defined
try {
    App::Clone::Linker->new({ 'paths' => { 'builds' => 't/linker/builds' } });
    fail("source path not defined");
} catch {
    pass("source path not defined");
};

## test source path not a directory
try {
    App::Clone::Linker->new({ 'paths' => { 'builds' => 't/linker/builds', 'sources' => 't/linker/sources-not-directory' } });
    fail("source path not a directory");
} catch {
    pass("source path not a directory");
};

## test source path not readable (missing readable)
try {
    try {
        umask(0);
        chmod(oct(333), 't/linker/sources-no-perms');
        pass("source path not writable (missing writable), could not change perms");
    } catch {
        my $error = (defined($_) ? $_ : "unknown error");
        fail("source path not writable (missing writable), could not change perms: ${error}");
    };
    App::Clone::Linker->new({ 'paths' => { 'builds' => 't/linker/builds', 'sources' => 't/linker/sources-no-perms' } });
    fail("source path not writable (missing writable)");
} catch {
    pass("source path not writable (missing writable)");
} finally {
    umask(0);
    chmod(oct(755), 't/linker/sources-no-perms');
};


## test source path not writable (missing executable)
try {
    try {
        umask(0);
        chmod(oct(666), 't/linker/sources-no-perms');
        pass("source path not writable (missing writable), could not change perms");
    } catch {
        my $error = (defined($_) ? $_ : "unknown error");
        fail("source path not writable (missing writable), could not change perms: ${error}");
    };
    App::Clone::Linker->new({ 'paths' => { 'builds' => 't/linker/builds', 'sources' => 't/linker/sources-no-perms' } });
    fail("source path not writable (missing writable)");
} catch {
    pass("source path not writable (missing writable)");
} finally {
    umask(0);
    chmod(oct(755), 't/linker/sources-no-perms');
};


## test source path not readable (missing both)
try {
    try {
        umask(0);
        chmod(oct(111), 't/linker/sources-no-perms');
        pass("source path not writable (missing both), could not change perms");
    } catch {
        my $error = (defined($_) ? $_ : "unknown error");
        fail("source path not writable (missing both), could not change perms: ${error}");
    };
    App::Clone::Linker->new({ 'paths' => { 'builds' => 't/linker/builds', 'sources' => 't/linker/sources-no-perms' } });
    fail("source path not writable (missing both)");
} catch {
    pass("source path not writable (missing both)");
} finally {
    umask(0);
    chmod(oct(755), 't/linker/sources-no-perms');
};


## test build path does not exist
try {
    try {
        umask(0);
        chmod(oct(000), 't/filter/builds-no-perms');
        pass("build path does not exist, could not change perms");
    } catch {
        my $error = (defined($_) ? $_ : "unknown error");
        fail("build path does not exist, could not change perms: ${error}");
    };
    App::Clone::Filter->new({ 'paths' => { 'builds' => 't/filter/builds-no-perms/builds', 'sources' => 't/linker/sources' } });
    fail("build path does not exist");
} catch {
    pass("build path does not exist");
} finally {
    umask(0);
    chmod(oct(755), 't/filter/builds-no-perms');
};


## test source path does not exist
try {
    try {
        umask(0);
        chmod(oct(000), 't/filter/sources-no-perms');
        pass("source path does not exist, could not change perms");
    } catch {
        my $error = (defined($_) ? $_ : "unknown error");
        fail("source path does not exist, could not change perms: ${error}");
    };
    App::Clone::Filter->new({ 'paths' => { 'builds' => 't/filter/builds/builds', 'sources' => 't/linker/sources-no-perms' } });
    fail("source path does not exist");
} catch {
    pass("source path does not exist");
} finally {
    umask(0);
    chmod(oct(755), 't/filter/sources-no-perms');
};


# remove any compiled hosts file
unlink('t/basics/conf/hosts.compiled');
ok(!(-e 't/basics/conf/hosts.compiled'), "compiled hosts file removed");

# now create a compiled hosts file but in test mode
my $hosts = App::Clone::Config->load('t/linker/conf/hosts', { 'test' => 1, 'skip_lookups' => 1, 'quiet' => 1 });

try {
    remove_tree('t/builds/example1');
    my $linker = App::Clone::Linker->new({ 'paths' => { 'sources' => 't/linker/sources', 'builds' => 't/linker/builds', 'tools' => 't/linker/tools' }, 'quiet' => 1 });

    umask(0);
    chmod(oct(755), 't/linker/sources/test/foo/etc');
    chmod(oct(775), 't/linker/sources/test/bar/etc');

    my %found = ();
    $linker->run($hosts->host('example1'));
    find(sub {
        $found{$File::Find::name} = 1;
    }, 't/linker/builds/example1');

    # check that all files got copied
    is_deeply(\%found, {
        't/linker/builds/example1' => 1,
        't/linker/builds/example1/etc' => 1,
        't/linker/builds/example1/usr' => 1,
        't/linker/builds/example1/usr/bin' => 1,
        't/linker/builds/example1/afile.txt' => 1,
        't/linker/builds/example1/etc/myfile.txt' => 1,
        't/linker/builds/example1/etc/yourfile.txt' => 1,
        't/linker/builds/example1/usr/bin/afile.txt' => 1,
    });

    # check that the link got created in the right way
    is(readlink('t/linker/builds/example1/usr/bin/afile.txt'), '../../afile.txt');
} catch {
    my $error = (defined($_) ? $_ : "unknown error");
    fail("basic test failed: ${error}");
};


done_testing();
