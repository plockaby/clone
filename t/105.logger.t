#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';

use Test::More;
use File::Path qw(remove_tree make_path);
use Try::Tiny;

use_ok("App::Clone::Logger") or BAIL_OUT("cannot test App::Clone::Logger as it is not compiling correctly");

# clean out the logs directory
remove_tree('t/basics/logs');

subtest "without IO::Tee" => sub {
    try {
        require Test::Without::Module;
    } catch {
        plan('skip_all' => 'Test::Without::Module not found.');
    };

    # make believe that IO::Tee isn't there (it might not be!)
    Test::Without::Module->import(qw(IO::Tee));


    ### test to see if stdout/stderr works without IO::Tee

    # create the output and ensure that it isn't an IO::Tee module
    my $logger1 = App::Clone::Logger->new('test1', { 'paths' => { 'logs' => 't/basics/logs' }, 'console' => 1 });
    ok(defined($logger1->stdout()) && !$logger1->stdout->isa('IO::Tee'));
    ok(defined($logger1->stderr()) && !$logger1->stderr->isa('IO::Tee'));

    # make sure the file that it said it created actually got created
    ok(-e $logger1->file(), "log file exists");

    # write to the log, close the log, see if it got written
    print { $logger1->stdout() } "hello\n";
    print { $logger1->stderr() } "goodbye\n";
    $logger1->handle->close();
    is(read_file($logger1->file()), "hello\ngoodbye\n", "contents written");

    # clean out the logs directory
    remove_tree('t/basics/logs');


    ### test to see if stdout works without IO::Tee and without asking for the console

    my $logger2 = App::Clone::Logger->new('test1', { 'paths' => { 'logs' => 't/basics/logs' }, 'console' => 0 });
    ok(defined($logger2->stdout()) && !$logger2->stdout->isa('IO::Tee'));
    ok(defined($logger2->stderr()) && !$logger2->stderr->isa('IO::Tee'));

    # make sure the file that it said it created does exist
    ok(-e $logger2->file(), "log file exists");

    # write to the log, close the log, see if it worked
    print { $logger2->stderr() } "again\n";
    $logger2->handle->close();
    is(read_file($logger2->file()), "again\n", "contents written");

    # clean out the logs directory
    remove_tree('t/basics/logs');


    ### re-enable IO::Tee
    Test::Without::Module->unimport(qw(IO::Tee));
};


### test to see if we get a file and the console when we use IO::Tee

my $logger3 = App::Clone::Logger->new('test2', { 'paths' => { 'logs' => 't/basics/logs' }, 'console' => 1 });
ok(defined($logger3->stdout()) && $logger3->stdout->isa('IO::Tee'));
ok(defined($logger3->stderr()) && $logger3->stderr->isa('IO::Tee'));

subtest "stdout test" => sub {
    try {
        require Test::Output;
    } catch {
        plan('skip_all' => 'Test::Output not found.');
    };

    # see if it comes out on the console
    Test::Output::combined_is(sub {
        print { $logger3->stdout() } "not again\n";
    }, "not again\n", undef, 'test1');

    # then see if it came out to the file
    $logger3->handle->close();
    is(read_file($logger3->file()), "not again\n", "contents written");

    done_testing();
};

# clean out the logs directory
remove_tree('t/basics/logs');

done_testing();

sub read_file {
    my $file = shift;

    open(my $fh, "<", $file) or die "could not open ${file}: $!\n";
    my $data = do { local $/ = undef; <$fh>; };
    close($fh);

    return $data;
}
