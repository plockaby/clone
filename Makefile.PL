#!/usr/bin/env perl

use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'         => 'App::Clone',
    'VERSION_FROM' => 'lib/App/Clone.pm',
    'PREREQ_PM'    => {
        'Config::Tiny'      => '0',
        'File::Which'       => '0',
        'File::Path'        => '0',
        'FindBin'           => '0',
        'Getopt::Long'      => '0',
        'IO::Interactive'   => '0',
        'Parse::RecDescent' => '0',
        'Try::Tiny'         => '0',
        'Pod::Usage'        => '0',
        'Storable'          => '0',
        'Test::More'        => '0',
        'Tie::IxHash'       => '0',
    },
    EXE_FILES => [
        'bin/clone',
        'bin/findsrc',
        'bin/deadsrc',
    ]
);
