#!/usr/bin/env perl

use strict;
use warnings;

my @initds = grep { /^\/etc\/init\.d/x } split(/:/x, $ENV{'FILES'});
for my $initd (@initds) {
    my ($program) = ($initd =~ /^\/etc\/init\.d\/(.+)$/x);

    print "### update-rc.d ${program} defaults";
    system("update-rc.d ${program} defaults");
}

