#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 28;
use Test::Warn;
use FindBin qw($Bin);
use lib "$Bin/../../lib";
use File::Temp qw(tempfile);
use Time::HiRes qw(time sleep);

# Set up logging to avoid warnings
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);

# Module to test
use_ok('SNMP::BIND9::Statistics');

# Create a mock statistics file for testing
my $stats_file = "$Bin/mock_stats.txt";
open my $fh, '>', $stats_file or die "Cannot create $stats_file: $!";
print $fh <<'EOF';
+++ Statistics Dump +++ (1650000000)
++ Incoming Queries ++
  100 A
  50 AAAA
  25 MX
  10 TXT
++ Outgoing Queries ++
  30 A
  15 AAAA
++ Name Server Statistics ++
  200 queries resulted in successful answer
  20 queries resulted in nxrrset
  10 queries resulted in nxdomain
  150 queries caused recursion
  100 recursive queries resulted in cache hit
  50 recursive queries resulted in cache miss
++ Zone Maintenance Statistics ++
  5 successful transfer in
  1 failed transfer in
  10 successful transfer out
  2 failed transfer out
EOF
close $fh;

# BASIC FUNCTIONALITY TESTS
subtest 'Basic object creation' => sub {
    plan tests => 3;
    
    my $stats = new_ok('SNMP::BIND9::Statistics' => [
        stats_file => $stats_file,
        rndc_command => 'echo "rndc stats"',  # Mock command that doesn't actually run rndc
        poll_interval => 60,
    ]);
    
    ok(defined $stats, 'Statistics object created');
    is(ref($stats), 'SNMP::BIND9::Statistics', 'Object is correct class');
};

# Test get_stats method
subtest 'Get stats functionality' => sub {
    plan tests => 3;
    
    my $stats = SNMP::BIND9::Statistics->new(
        stats_file => $stats_file,
        rndc_command => 'echo "rndc stats"',
        poll_interval => 60,
    );
    
    my $all_stats = $stats->get_stats();
    ok(defined $all_stats, 'get_stats returns defined value');
    ok(ref($all_stats) eq 'HASH', 'get_stats returns a hashref');
    cmp_ok(scalar(keys %$all_stats), '>', 10, 'Stats hashref contains multiple keys');
};

# Test specific statistics retrieval
subtest 'Statistics retrieval' => sub {
    plan tests => 9;
    
    my $stats = SNMP::BIND9::Statistics->new(
        stats_file => $stats_file,
        rndc_command => 'echo "rndc stats"',
        poll_interval => 60,
    );
    
    # Test query types
    is($stats->get_stat('query_type_A'), 100, 'get_stat returns correct value for query_type_A');
    is($stats->get_stat('query_type_AAAA'), 50, 'get_stat returns correct value for query_type_AAAA');
    is($stats->get_stat('query_type_MX'), 25, 'get_stat returns correct value for query_type_MX');
    
    # Test outgoing queries
    is($stats->get_stat('outgoing_query_type_A'), 30, 'get_stat returns correct value for outgoing_query_type_A');
    
    # Test server stats
    is($stats->get_stat('queries_success'), 200, 'get_stat returns correct value for queries_success');
    is($stats->get_stat('queries_failure'), 30, 'get_stat returns combined value for queries_failure');
    
    # Test zone stats
    is($stats->get_stat('zone_successful_transfer_in'), 5, 'get_stat returns correct zone stat');
    is($stats->get_stat('zone_successful_transfer_out'), 10, 'get_stat for zone stats works');
    
    # Test nonexistent stat
    is($stats->get_stat('nonexistent_stat'), undef, 'get_stat returns undef for nonexistent stat');
};

# Test derived statistics
subtest 'Derived statistics' => sub {
    plan tests => 2;
    
    my $stats = SNMP::BIND9::Statistics->new(
        stats_file => $stats_file,
        rndc_command => 'echo "rndc stats"',
        poll_interval => 60,
    );
    
    # Test cache hit ratio calculation
    my $cache_hit_ratio = $stats->get_stat('cache_hit_ratio');
    ok(defined $cache_hit_ratio, 'cache_hit_ratio is defined');
    is($cache_hit_ratio, '66.67', 'cache_hit_ratio calculated correctly (100/(100+50)*100)');
};

# Test poll interval and caching behavior
subtest 'Poll interval and caching' => sub {
    plan tests => 3;
    
    # Use a short poll interval for testing
    my $stats = SNMP::BIND9::Statistics->new(
        stats_file => $stats_file,
        rndc_command => 'echo "rndc stats"',
        poll_interval => 1,  # 1 second
    );
    
    # First call should always collect
    my $first_time = $stats->{last_poll_time};
    ok($first_time > 0, 'Initial collection time recorded');
    
    # Second call immediately should not collect
    $stats->collect_stats();
    is($stats->{last_poll_time}, $first_time, 'Stats not collected when within poll interval');
    
    # Wait for poll interval to expire
    sleep(1.1);
    $stats->collect_stats();
    cmp_ok($stats->{last_poll_time}, '>', $first_time, 'Stats collected after poll interval expires');
};

# Test force refresh
subtest 'Force refresh' => sub {
    plan tests => 2;
    
    my $stats = SNMP::BIND9::Statistics->new(
        stats_file => $stats_file,
        rndc_command => 'echo "rndc stats"',
        poll_interval => 60,  # Long poll interval
    );
    
    my $first_time = $stats->{last_poll_time};
    
    # Force refresh should collect even within poll interval
    $stats->collect_stats(1);  # Force parameter = 1
    cmp_ok($stats->{last_poll_time}, '>', $first_time, 'Force parameter triggered collection');
    
    my $second_time = $stats->{last_poll_time};
    
    # Force parameter via get_stats
    $stats->get_stats(1);  # Force refresh = 1
    cmp_ok($stats->{last_poll_time}, '>', $second_time, 'Force refresh via get_stats triggered collection');
};

# ERROR HANDLING TESTS
subtest 'Invalid file handling' => sub {
    plan tests => 2;
    
    # Test with nonexistent file
    my $nonexistent_file = "$Bin/nonexistent_file.txt";
    my $stats;
    
    warning_like {
        $stats = SNMP::BIND9::Statistics->new(
            stats_file => $nonexistent_file,
            rndc_command => 'echo "rndc stats"',
        );
    } qr/Failed to collect initial statistics/, 'Warning issued for nonexistent file';
    
    ok(scalar(@{$stats->{errors}}) > 0, 'Error recorded in errors array');
};

subtest 'Command failure handling' => sub {
    plan tests => 2;
    
    # Test with a command that will fail
    my $stats = SNMP::BIND9::Statistics->new(
        stats_file => $stats_file,
        rndc_command => 'false',  # Command that always exits with error
        poll_interval => 1,
    );
    
    # Wait a bit to ensure we're outside the poll interval
    sleep(1.1);
    
    # Test collecting stats with a failing command
    my $result;
    warning_like {
        $result = $stats->collect_stats();
    } qr/Failed to run/, 'Warning issued for failed command';
    
    ok(defined $result, 'collect_stats returns a value even with command failure');
};

subtest 'Malformed stats file handling' => sub {
    plan tests => 2;
    
    # Create a malformed stats file
    my ($malformed_fh, $malformed_file) = tempfile(UNLINK => 1);
    print $malformed_fh "This is not a valid stats file format\n";
    close $malformed_fh;
    
    my $stats = SNMP::BIND9::Statistics->new(
        stats_file => $malformed_file,
        rndc_command => 'echo "rndc stats"',
    );
    
    # Test parsing behavior with malformed file
    warning_like {
        $stats->collect_stats(1);  # Force refresh
    } qr/No sections found/, 'Warning issued for malformed stats file';
    
    my $all_stats = $stats->get_stats();
    ok(scalar(keys %$all_stats) > 0, 'Basic stats initialized even with malformed file');
};

# Clean up
unlink $stats_file;
