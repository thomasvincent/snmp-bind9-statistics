#!/usr/bin/env perl

use 5.010;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'SNMP::BIND9::Statistics',
    AUTHOR           => q{Thomas Vincent <thomasvincent@example.com>},
    VERSION_FROM     => 'lib/SNMP/BIND9/Statistics.pm',
    ABSTRACT         => 'Perl script collects and displays BIND9 DNS server statistics via SNMP',
    LICENSE          => 'mit',
    MIN_PERL_VERSION => '5.010',
    EXE_FILES        => ['bin/snmp_bind9_stats.pl'],
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => '6.64', # For TEST_REQUIRES support
    },
    TEST_REQUIRES => {
        'Test::More'       => '0.88',
        'Test::MockObject' => '1.20',
        'Test::Warn'       => '0.30',
        'File::Temp'       => '0.22',
        'Time::HiRes'      => '1.9725',
    },
    PREREQ_PM => {
        'Net::SNMP'        => '6.0.0',
        'File::Slurp'      => '9999.19',
        'Log::Log4perl'    => '1.49',
        'Config::IniFiles' => '2.94',
        'Try::Tiny'        => '0.30',
        'Scalar::Util'     => '1.50',
        'File::Spec'       => '3.40',
        'IPC::Cmd'         => '0.92',
        'Time::HiRes'      => '1.9725',
        'Carp'             => '1.26',
        'POSIX'            => '1.38',
        'FindBin'          => '1.50',
        'Getopt::Long'     => '2.42',
        'Pod::Usage'       => '1.63',
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'SNMP-BIND9-Statistics-*' },
    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources => {
            repository => {
                type => 'git',
                url  => 'https://github.com/thomasvincent/snmp-bind9-statistics.git',
                web  => 'https://github.com/thomasvincent/snmp-bind9-statistics',
            },
            bugtracker => {
                web => 'https://github.com/thomasvincent/snmp-bind9-statistics/issues',
            },
            homepage => 'https://github.com/thomasvincent/snmp-bind9-statistics',
        },
        keywords => ['SNMP', 'BIND9', 'DNS', 'monitoring', 'statistics'],
    },
);
