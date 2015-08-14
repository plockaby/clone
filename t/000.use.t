#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';

use Test::More;

BEGIN {
    use_ok('App::Clone');
    use_ok('App::Clone::Config');
    use_ok('App::Clone::Logger');
    use_ok('App::Clone::Parser');
    use_ok('App::Clone::Parser::Host');
    use_ok('App::Clone::Linker');
    use_ok('App::Clone::Linker::Directory');
    use_ok('App::Clone::Filter');
    use_ok('App::Clone::Runner');
};

done_testing();
