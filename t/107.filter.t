#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';

use Test::More;
use File::Path qw(remove_tree make_path);
use Storable qw(lock_retrieve);
use Try::Tiny;

use_ok("App::Clone::Config") or BAIL_OUT("cannot test App::Clone::Config as it is not compiling correctly");
use_ok("App::Clone::Filter") or BAIL_OUT("cannot test App::Clone::Filter as it is not compiling correctly");

## test build path not defined
try {
    App::Clone::Filter->new({ 'paths' => {} });
    fail("build path not defined");
} catch {
    pass("build path not defined");
};

## test build path not a directory
try {
    App::Clone::Filter->new({ 'paths' => { 'builds' => 't/filter/builds-not-directory' } });
    fail("build path not a directory");
} catch {
    pass("build path not a directory");
};

## test build path not writable (missing writable)
try {
    try {
        umask(0);
        chmod(oct(555), 't/filter/builds-no-perms');
        pass("build path not writable (missing writable), could not change perms");
    } catch {
        my $error = (defined($_) ? $_ : "unknown error");
        fail("build path not writable (missing writable), could not change perms: ${error}");
    };
    App::Clone::Filter->new({ 'paths' => { 'builds' => 't/filter/builds-no-perms' } });
    fail("build path not writable (missing writable)");
} catch {
    pass("build path not writable (missing writable)");
} finally {
    umask(0);
    chmod(oct(755), 't/filter/builds-no-perms');
};


## test build path not writable (missing executable)
try {
    try {
        umask(0);
        chmod(oct(666), 't/filter/builds-no-perms');
        pass("build path not writable (missing writable), could not change perms");
    } catch {
        my $error = (defined($_) ? $_ : "unknown error");
        fail("build path not writable (missing writable), could not change perms: ${error}");
    };
    App::Clone::Filter->new({ 'paths' => { 'builds' => 't/filter/builds-no-perms' } });
    fail("build path not writable (missing writable)");
} catch {
    pass("build path not writable (missing writable)");
} finally {
    umask(0);
    chmod(oct(755), 't/filter/builds-no-perms');
};


## test build path not writable (missing both)
try {
    try {
        umask(0);
        chmod(oct(444), 't/filter/builds-no-perms');
        pass("build path not writable (missing both), could not change perms");
    } catch {
        my $error = (defined($_) ? $_ : "unknown error");
        fail("build path not writable (missing both), could not change perms: ${error}");
    };
    App::Clone::Filter->new({ 'paths' => { 'builds' => 't/filter/builds-no-perms' } });
    fail("build path not writable (missing both)");
} catch {
    pass("build path not writable (missing both)");
} finally {
    umask(0);
    chmod(oct(755), 't/filter/builds-no-perms');
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
    App::Clone::Filter->new({ 'paths' => { 'builds' => 't/filter/builds-no-perms/builds' } });
    fail("build path does not exist");
} catch {
    pass("build path does not exist");
} finally {
    umask(0);
    chmod(oct(755), 't/filter/builds-no-perms');
};


# remove any compiled hosts file
unlink('t/basics/conf/hosts.compiled');
ok(!(-e 't/basics/conf/hosts.compiled'), "compiled hosts file removed");

# now create a compiled hosts file but in test mode
my $hosts = App::Clone::Config->load('t/filter/conf/hosts', { 'test' => 1, 'skip_lookups' => 1, 'quiet' => 1 });

try {
    # remove things before we start
    unlink('t/filter/builds/example1/filter_');
    ok(!(-e 't/filter/builds/example1/filter_'));
    unlink('t/filter/builds/example1/usr/local/ref/commands');
    ok(!(-e 't/filter/builds/example1/usr/local/ref/commands'));

    my $filter = App::Clone::Filter->new({ 'paths' => { 'builds' => 't/filter/builds' }, 'quiet' => 1, 'home' => '/usr/local/ref' });

    $filter->run($hosts->host('example1'));
    ok(-e 't/filter/builds/example1/filter_');
    is(read_file('t/filter/builds/example1/filter_'), "- /etc\n- /var\nrisk /***\nprotect /***\n");

    ok(-e 't/filter/builds/example1/usr/local/ref/commands');
    my $commands = lock_retrieve('t/filter/builds/example1/usr/local/ref/commands');
    is_deeply($commands, {});
} catch {
    my $error = (defined($_) ? $_ : "unknown error");
    fail("basic test failed: ${error}");
};


try {
    unlink('t/filter/builds/example2/filter_');
    ok(!(-e 't/filter/builds/example2/filter_'));
    unlink('t/filter/builds/example2/usr/local/ref/commands');
    ok(!(-e 't/filter/builds/example2/usr/local/ref/commands'));

    my $filter = App::Clone::Filter->new({ 'paths' => { 'builds' => 't/filter/builds' }, 'quiet' => 1, 'home' => '/usr/local/ref' });

    $filter->run($hosts->host('example2'));
    ok(-e 't/filter/builds/example2/filter_');
    is(read_file('t/filter/builds/example2/filter_'), "- /etc\n- /var\nprotect /***\n");

    ok(-e 't/filter/builds/example2/usr/local/ref/commands');
    my $commands = lock_retrieve('t/filter/builds/example2/usr/local/ref/commands');
    is_deeply($commands, {});
} catch {
    my $error = (defined($_) ? $_ : "unknown error");
    fail("basic test failed: ${error}");
};


try {
    # remove things before we start
    unlink('t/filter/builds/example3/filter_');
    ok(!(-e 't/filter/builds/example3/filter_'));
    unlink('t/filter/builds/example3/usr/local/ref/commands');
    ok(!(-e 't/filter/builds/example3/usr/local/ref/commands'));

    my $filter = App::Clone::Filter->new({ 'paths' => { 'builds' => 't/filter/builds' }, 'quiet' => 1, 'home' => '/usr/local/ref' });

    # now see if filter_ exists and commands exist
    $filter->run($hosts->host('example3'));
    ok(-e 't/filter/builds/example3/filter_');
    is(read_file('t/filter/builds/example3/filter_'), "- /var\n-p *.pyc\nrisk /etc/ssh/***\nprotect /***\n");

    ok(-e 't/filter/builds/example3/usr/local/ref/commands');
    my $commands1 = lock_retrieve('t/filter/builds/example3/usr/local/ref/commands');
    is_deeply($commands1, {
        'ssh' => [
            '^/etc/default/ssh',
            '^/etc/ssh/ssh_host_.*',
            '^/etc/ssh/sshd_config',
        ]
    });
} catch {
    my $error = (defined($_) ? $_ : "unknown error");
    fail("basic test failed: ${error}");
};


try {
    # remove things before we start
    unlink('t/filter/builds/example4/filter_');
    ok(!(-e 't/filter/builds/example4/filter_'));
    unlink('t/filter/builds/example4/usr/local/ref/commands');
    ok(!(-e 't/filter/builds/example4/usr/local/ref/commands'));
    remove_tree('t/filter/builds/example4/foo1');
    remove_tree('t/filter/builds/example4/foo2');
    remove_tree('t/filter/builds/example4/foo3');
    remove_tree('t/filter/builds/example4/foo4');
    remove_tree('t/filter/builds/example4/foo5');
    remove_tree('t/filter/builds/example4/foo6');

    my $filter = App::Clone::Filter->new({ 'paths' => { 'builds' => 't/filter/builds' }, 'quiet' => 1, 'home' => '/usr/local/ref' });

    # now see if filter_ exists and commands exist
    $filter->run($hosts->host('example4'));
    ok(-e 't/filter/builds/example4/filter_');
    is(read_file('t/filter/builds/example4/filter_'), "- /foo1/bar\n- /foo2/bar/*/baz\n- /foo3/bar/**/baz.[0-9][0-9]*\n- /foo4/bar/baz/[^.]*\n- /foo5/bar/baz/[a-z]*\n- /foo6/bar/baz/[0-9][0-9]\nprotect /***\n");

    ok(-e 't/filter/builds/example4/usr/local/ref/commands');
    my $commands = lock_retrieve('t/filter/builds/example4/usr/local/ref/commands');
    is_deeply($commands, {});

    # now ensure that directories got created to match the exceptions

    # test /foo1/bar
    ok(-e 't/filter/builds/example4/foo1');
    opendir(my $dh1, 't/filter/builds/example4/foo1') or die "could not open t/filter/builds/example4/foo1: $!\n";
    is(scalar(grep { ! /^\.+$/x } readdir($dh1)), 0, "foo1");
    closedir($dh1);

    # test /foo2/bar/*/baz
    ok(-e 't/filter/builds/example4/foo2/bar');
    opendir(my $dh2, 't/filter/builds/example4/foo2/bar') or die "could not open t/filter/builds/example4/foo2/bar: $!\n";
    is(scalar(grep { ! /^\.+$/x } readdir($dh2)), 0, "foo2");
    closedir($dh2);

    # test /foo3/bar/**/baz.[0-9][0-9]*
    ok(-e 't/filter/builds/example4/foo3/bar');
    opendir(my $dh3, 't/filter/builds/example4/foo3/bar') or die "could not open t/filter/builds/example4/foo3/bar: $!\n";
    is(scalar(grep { ! /^\.+$/x } readdir($dh3)), 0, "foo3");
    closedir($dh3);

    # test /foo4/bar/baz/[^.]*
    ok(-e 't/filter/builds/example4/foo4/bar/baz');
    opendir(my $dh4, 't/filter/builds/example4/foo4/bar/baz') or die "could not open t/filter/builds/example4/foo4/bar/baz: $!\n";
    is(scalar(grep { ! /^\.+$/x } readdir($dh4)), 0, "foo4");
    closedir($dh4);

    # test /foo5/bar/baz/[a-z]*
    ok(-e 't/filter/builds/example4/foo5/bar/baz');
    opendir(my $dh5, 't/filter/builds/example4/foo5/bar/baz') or die "could not open t/filter/builds/example4/foo5/bar/baz: $!\n";
    is(scalar(grep { ! /^\.+$/x } readdir($dh5)), 0, "foo5");
    closedir($dh5);

    # test /foo6/bar/baz/[0-9][0-9]
    ok(-e 't/filter/builds/example4/foo6/bar/baz');
    opendir(my $dh6, 't/filter/builds/example4/foo6/bar/baz') or die "could not open t/filter/builds/example4/foo6/bar/baz: $!\n";
    is(scalar(grep { ! /^\.+$/x } readdir($dh6)), 0, "foo6");
    closedir($dh6);
} catch {
    my $error = (defined($_) ? $_ : "unknown error");
    fail("basic test failed: ${error}");
};


done_testing();

sub read_file {
    my $file = shift;

    open(my $fh, "<", $file) or die "could not open ${file}: $!\n";
    my $data = do { local $/ = undef; <$fh>; };
    close($fh);

    return $data;
}
