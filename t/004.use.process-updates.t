#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';

use Test::More;

require_ok("./tools/process-updates") or BAIL_OUT("cannot test process-updates as it is not compiling correctly");

done_testing();
