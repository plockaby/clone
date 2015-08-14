#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';

use Test::More;

require_ok("./bin/clone") or BAIL_OUT("cannot test clone as it is not compiling correctly");

done_testing();
