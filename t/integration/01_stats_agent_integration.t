#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 17;
use Test::Warn;
use FindBin qw($Bin);
use lib "$Bin/../../lib";
use File::Temp qw(tempfile);
use Time::HiRes qw(sleep);

# Set up logging to avoid test output pollution
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);

# Modules to test
use_ok('SNMP::BIND9::Statistics');
use_ok('SNMP::BIND9::Agent');

# Create a comprehensive temporary file for testing
my $stats_file = "$Bin/mock_stats.txt";
open my $fh, '>', $stats_file or die "Cannot create $stats_file: $!";
print $fh <<'EOF';
+++ Statistics Dump +++ (1650000000)
++ Incoming Queries ++
  100 A
  50 AAAA
  25 MX
  10 TXT
  5 NS
  3 PTR
  2 SOA
  1 SRV
++ Outgoing Queries ++
  30 A
  15 AAAA
  5 MX
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

# STATISTICS AND AGENT INITIALIZATION
subtest 'Statistics and Agent Initialization' => sub {
    plan tests => 4;
    
    # Create Statistics object
    my $stats = new_ok('SNMP::BIND9::Statistics' => [
        stats_file => $stats_file,
        rndc_command => 'echo "rndc stats"',  # Mock command that doesn't actually run rndc
        poll_interval => 1,  # Short poll interval for testing
    ]);
    
    # Create Agent object
    my $agent = new_ok('SNMP::BIND9::Agent' => [
        stats => $stats,
        community => 'public',
        port => 8161,  # Use non-standard port for testing
        agent_addr => '127.0.0.1',
    ]);
    
    # Verify connectivity between objects
    ok(defined $agent->{stats}, 'Agent has reference to statistics object');
    is($agent->{stats}, $stats, 'Reference points to the correct statistics object');
};

# VERIFY STATISTICS COLLECTION
subtest 'Statistics Collection' => sub {
    plan tests => 4;
    
    my $stats = SNMP::BIND9::Statistics->new(
        stats_file => $stats_file,
        rndc_command => 'echo "Updated stats"',
        poll_interval => 1,
    );
    
    # Verify initial stats collection
    ok($stats->get_stat('queries_total') == 100 + 50 + 25 + 10 + 5 + 3 + 2 + 1, 
       'Initial stats collection has correct query total');
    
    # Verify specific stats
    is($stats->get_stat('query_type_A'), 100, 'A query count is correct');
    is($stats->get_stat('cache_hits'), 100, 'Cache hits count is correct');
    is($stats->get_stat('cache_hit_ratio'), '66.67', 'Cache hit ratio is calculated correctly');
};

# TEST STATISTICS POLLING
subtest 'Statistics Polling Behavior' => sub {
    plan tests => 3;
    
    my $stats = SNMP::BIND9::Statistics->new(
        stats_file => $stats_file,
        rndc_command => 'echo "Updated"',
        poll_interval => 1,  # 1 second for quick testing
    );
    
    # Initial collection time
    my $initial_time = $stats->{last_poll_time};
    ok($initial_time > 0, 'Initial collection timestamp recorded');
    
    # Immediate poll should use cached data
    $stats->collect_stats();
    is($stats->{last_poll_time}, $initial_time, 'Cached data used within poll interval');
    
    # Wait for poll interval to expire
    sleep(1.1);
    $stats->collect_stats();
    cmp_ok($stats->{last_poll_time}, '>', $initial_time, 'Fresh data collected after poll interval');
};

# TEST AGENT OID MAPPING
subtest 'Agent OID Mapping' => sub {
    plan tests => 3;
    
    my $stats = SNMP::BIND9::Statistics->new(
        stats_file => $stats_file,
        rndc_command => 'echo "rndc stats"',
        poll_interval => 60,
    );
    
    my $agent = SNMP::BIND9::Agent->new(
        stats => $stats,
        community => 'public',
        port => 8161,
    );
    
    # Verify OID map structure
    ok(exists $SNMP::BIND9::Agent::OID_MAP{queries_total}, 'OID map contains queries_total');
    
    # Test reverse lookup in OID tree
    my $queries_total_oid = $SNMP::BIND9::Agent::OID_MAP{queries_total};
    ok(exists $agent->{oid_tree}{$queries_total_oid}, 'OID tree contains entry for queries_total');
    is($agent->{oid_tree}{$queries_total_oid}, 'queries_total', 'OID tree maps back correctly');
};

# TEST SNMP GET HANDLING
subtest 'SNMP GET Request Handling' => sub {
    plan tests => 3;
    
    my $stats = SNMP::BIND9::Statistics->new(
        stats_file => $stats_file,
        rndc_command => 'echo "rndc stats"',
        poll_interval => 60,
    );
    
    my $agent = SNMP::BIND9::Agent->new(
        stats => $stats,
        community => 'public',
        port => 8161,
    );
    
    # Test direct GET handler (internal method)
    my $queries_total_oid = $SNMP::BIND9::Agent::OID_MAP{queries_total};
    my $value = $agent->_handle_get_request($queries_total_oid);
    ok(defined $value, 'GET handler returns a value');
    is($value, 196, 'GET handler returns correct value');
    
    # Test GET with unknown OID
    my $unknown_oid = '.1.3.6.1.4.1.99999.999';
    my $error_value = $agent->_handle_get_request($unknown_oid);
    is($error_value, Net::SNMP::SNMP_NOSUCHOBJECT(), 'GET handler handles unknown OIDs correctly');
};

# TEST SNMP GETNEXT HANDLING
subtest 'SNMP GETNEXT Request Handling' => sub {
    plan tests => 4;
    
    my $stats = SNMP::BIND9::Statistics->new(
        stats_file => $stats_file,
        rndc_command => 'echo "rndc stats"',
        poll_interval => 60,
    );
    
    my $agent = SNMP::BIND9::Agent->new(
        stats => $stats,
        community => 'public',
        port => 8161,
    );
    
    # Test GETNEXT from base OID
    my $base_oid = $SNMP::BIND9::Agent::OID_BASE;
    my ($next_oid, $next_value) = $agent->_handle_getnext_request($base_oid);
    ok(defined $next_oid, 'GETNEXT returns next OID');
    ok(defined $next_value, 'GETNEXT returns value for next OID');
    ok($next_oid gt $base_oid, 'Next OID is lexicographically greater than base OID');
    
    # Test GETNEXT at end of tree
    my @oids = sort keys %{$agent->{oid_tree}};
    my $last_oid = $oids[-1];
    my ($beyond_oid, $beyond_value) = $agent->_handle_getnext_request($last_oid);
    ok(!defined $beyond_oid, 'GETNEXT at end of tree returns undef');
};

# TEST ERROR HANDLING
subtest 'Error Handling' => sub {
    plan tests => 3;
    
    # Test stats file handling errors
    my $nonexistent_file = "$Bin/nonexistent_file.txt";
    my $stats;
    
    warning_like {
        $stats = SNMP::BIND9::Statistics->new(
            stats_file => $nonexistent_file,
            rndc_command => 'echo "rndc stats"',
        );
    } qr/Failed to collect initial statistics/, 'Warning issued for nonexistent file';
    
    # Test command failure
    my $bad_command_stats = SNMP::BIND9::Statistics->new(
        stats_file => $stats_file,
        rndc_command => 'false',  # Command that will fail
        poll_interval => 1,
    );
    
    # Wait for poll interval to expire
    sleep(1.1);
    
    # Test collecting stats with a failing command
    warning_like {
        $bad_command_stats->collect_stats();
    } qr/Failed to run/, 'Warning issued for failed command';
    
    # Verify stats still exist despite command failure
    ok(scalar(keys %{$bad_command_stats->get_stats()}) > 0, 'Stats still available despite command failure');
};

# TEST END-TO-END STATISTICS FLOW
subtest 'End-to-End Statistics Flow' => sub {
    plan tests => 4;
    
    # Create a different stats file for this test
    my ($updated_fh, $updated_file) = tempfile(UNLINK => 1);
    print $updated_fh <<'EOF';
+++ Statistics Dump +++ (1650000001)
++ Incoming Queries ++
  200 A
  100 AAAA
++ Name Server Statistics ++
  300 queries resulted in successful answer
EOF
    close $updated_fh;
    
    # Create stats object with initial file
    my $stats = SNMP::BIND9::Statistics->new(
        stats_file => $stats_file,
        rndc_command => "cp $updated_file $stats_file",  # Update the stats file
        poll_interval => 1,
    );
    
    # Create agent with stats
    my $agent = SNMP::BIND9::Agent->new(
        stats => $stats,
        community => 'public',
        port => 8161,
    );
    
    # Verify initial values
    is($stats->get_stat('query_type_A'), 100, 'Initial A query count is correct');
    
    # Wait for poll interval and force update
    sleep(1.1);
    $stats->collect_stats(1);  # Force refresh
    
    # Verify stats were updated
    is($stats->get_stat('query_type_A'), 200, 'Updated A query count is correct');
    is($stats->get_stat('query_type_AAAA'), 100, 'Updated AAAA query count is correct');
    
    # Verify agent can access the updated stats
    my $queries_total_oid = $SNMP::BIND9::Agent::OID_MAP{queries_total};
    my $value = $agent->_handle_get_request($queries_total_oid);
    is($value, 300, 'Agent has access to updated statistics');
    
    # Clean up
    unlink $updated_file if -e $updated_file;
};

# Clean up
unlink $stats_file;
