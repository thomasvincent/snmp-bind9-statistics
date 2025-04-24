#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 9;
use Test::Warn;
use Test::MockObject;
use FindBin qw($Bin);
use lib "$Bin/../../lib";

# Set up logging to avoid warnings
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);

# Mock Net::SNMP package for testing SNMP operations
BEGIN {
    # Create a mock for Net::SNMP
    package MockSNMP;
    
    # Store test state
    our $session_created = 0;
    our $session_closed = 0;
    our $callback_registered = 0;
    our $callback_fn = undef;
    our $callback_arg = undef;
    our $dispatcher_created = 0;
    our $pdu_type = 0; # Default to GET
    our $last_var_bind_list = undef;
    
    # Constants
    use constant SNMP_MSG_GET => 0;
    use constant SNMP_MSG_GETNEXT => 1;
    use constant SNMP_NOSUCHOBJECT => 'noSuchObject';
    
    # Reset all test state
    sub reset {
        $session_created = 0;
        $session_closed = 0;
        $callback_registered = 0;
        $callback_fn = undef;
        $callback_arg = undef;
        $dispatcher_created = 0;
        $pdu_type = 0;
        $last_var_bind_list = undef;
    }
    
    # Create a mock session 
    sub session {
        my ($class, %args) = @_;
        $session_created = 1;
        
        # Return a mock session object and no error
        return (bless({
            hostname => $args{-hostname},
            port => $args{-port},
            community => $args{-community}
        }, 'MockSession'), undef);
    }
    
    # Create a mock dispatcher
    sub master_dispatcher {
        $dispatcher_created = 1;
        return (bless({}, 'MockDispatcher'), undef);
    }
    
    # Mock session methods
    package MockSession;
    
    sub register_callback {
        my ($self, %args) = @_;
        $MockSNMP::callback_registered = 1;
        $MockSNMP::callback_fn = $args{callback};
        $MockSNMP::callback_arg = $args{callback_arg};
        return 1;
    }
    
    sub close {
        $MockSNMP::session_closed = 1;
        return 1;
    }
    
    sub error {
        return "Mock SNMP error";
    }
    
    sub pdu_type {
        return $MockSNMP::pdu_type;
    }
    
    sub var_bind_list {
        my ($self, $response) = @_;
        
        # If response is provided, store it and return
        if (defined $response) {
            $MockSNMP::last_var_bind_list = $response;
            return 1;
        }
        
        # Otherwise return a test PDU based on PDU type
        if ($MockSNMP::pdu_type == 0) { # GET
            return {
                '.1.3.6.1.4.1.8767.2.1.1.1' => 'queries_total',
                '.1.3.6.1.4.1.8767.2.1.1.2' => 'queries_success'
            };
        } else { # GETNEXT
            return {
                '.1.3.6.1.4.1.8767.2.1' => 'getnext_base_oid'
            };
        }
    }
    
    # Method to trigger the callback for testing
    sub trigger_callback {
        my ($self) = @_;
        if ($MockSNMP::callback_fn) {
            $MockSNMP::callback_fn->($self, $MockSNMP::callback_arg);
            return 1;
        }
        return 0;
    }
    
    # Mock dispatcher methods
    package MockDispatcher;
    
    sub one_event {
        my ($self, $timeout) = @_;
        # Just return success
        return 1;
    }
    
    # Back to main package
    package main;
    
    # Override Net::SNMP with our mock
    $INC{'Net/SNMP.pm'} = 1;
    no warnings 'once';
    *Net::SNMP::session = \&MockSNMP::session;
    *Net::SNMP::master_dispatcher = \&MockSNMP::master_dispatcher;
    *Net::SNMP::SNMP_MSG_GET = \&MockSNMP::SNMP_MSG_GET;
    *Net::SNMP::SNMP_MSG_GETNEXT = \&MockSNMP::SNMP_MSG_GETNEXT;
    *Net::SNMP::SNMP_NOSUCHOBJECT = \&MockSNMP::SNMP_NOSUCHOBJECT;
}

# Now load the modules to test
use_ok('SNMP::BIND9::Agent');
use_ok('SNMP::BIND9::Statistics');

# Create a more comprehensive mock statistics file for testing
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

# Create a Statistics object for testing
my $stats = SNMP::BIND9::Statistics->new(
    stats_file => $stats_file,
    rndc_command => 'echo "rndc stats"',
    poll_interval => 60,
);

# BASIC FUNCTIONALITY TESTS
subtest 'Basic Agent functionality' => sub {
    plan tests => 6;

    # Reset mock state
    MockSNMP::reset();
    
    # Create an Agent object with the Statistics object
    my $agent = new_ok('SNMP::BIND9::Agent' => [
        stats => $stats,
        community => 'public',
        port => 161,
        agent_addr => '127.0.0.1',
    ]);
    
    # Test object properties
    ok(defined $agent->{stats}, 'Stats object is assigned');
    is($agent->{community}, 'public', 'Community string is set');
    is($agent->{port}, 161, 'Port is set');
    is($agent->{agent_addr}, '127.0.0.1', 'Agent address is set');
    ok(exists $agent->{oid_tree}, 'OID tree is initialized');
};

# TEST OID MAPPING
subtest 'OID mapping' => sub {
    plan tests => 4;
    
    # Reset mock state
    MockSNMP::reset();
    
    my $agent = SNMP::BIND9::Agent->new(
        stats => $stats,
        community => 'public',
        port => 161,
        agent_addr => '127.0.0.1',
    );
    
    # Test OID mappings
    ok(exists $SNMP::BIND9::Agent::OID_MAP{queries_total}, 'OID map contains queries_total');
    ok(exists $SNMP::BIND9::Agent::OID_MAP{query_type_A}, 'OID map contains query_type_A');
    ok(exists $SNMP::BIND9::Agent::OID_MAP{zone_successful_transfer_in}, 'OID map contains zone stats');
    
    # Test OID tree population
    ok(exists $agent->{oid_tree}{$SNMP::BIND9::Agent::OID_MAP{queries_total}}, 
       'OID tree maps back to stat name');
};

# TEST AGENT INITIALIZATION
subtest 'Agent initialization' => sub {
    plan tests => 5;
    
    # Reset mock state
    MockSNMP::reset();
    
    my $agent = SNMP::BIND9::Agent->new(
        stats => $stats,
        community => 'public',
        port => 161,
        agent_addr => '127.0.0.1',
    );
    
    # Test initialization
    ok($agent->init_agent(), 'Agent initializes successfully');
    ok($MockSNMP::session_created, 'SNMP session was created');
    ok($MockSNMP::dispatcher_created, 'SNMP dispatcher was created');
    ok($MockSNMP::callback_registered, 'Callback was registered');
    ok(defined $agent->{session}, 'Session is stored in agent object');
};

# TEST AGENT LIFECYCLE
subtest 'Agent lifecycle' => sub {
    plan tests => 6;
    
    # Reset mock state
    MockSNMP::reset();
    
    my $agent = SNMP::BIND9::Agent->new(
        stats => $stats,
        community => 'public',
        port => 161,
        agent_addr => '127.0.0.1',
    );
    
    # Test run method
    ok($agent->init_agent(), 'Agent initializes successfully');
    ok($agent->run(), 'Agent runs successfully');
    ok($agent->is_running(), 'Agent is marked as running');
    
    # Test event processing
    ok($agent->process_events(0.1), 'Agent processes events');
    
    # Test stop method
    ok($agent->stop(), 'Agent stops successfully');
    ok($MockSNMP::session_closed, 'SNMP session was closed');
};

# TEST SNMP GET REQUEST HANDLING
subtest 'SNMP GET request' => sub {
    plan tests => 3;
    
    # Reset mock state
    MockSNMP::reset();
    $MockSNMP::pdu_type = 0; # GET
    
    my $agent = SNMP::BIND9::Agent->new(
        stats => $stats,
        community => 'public',
        port => 161,
        agent_addr => '127.0.0.1',
    );
    
    # Initialize agent
    $agent->init_agent();
    
    # Trigger the callback that would normally be called by Net::SNMP
    my $session = $agent->{session};
    ok($session->trigger_callback(), 'GET callback triggered');
    
    # Verify response
    ok(defined $MockSNMP::last_var_bind_list, 'Response was generated');
    ok(scalar(keys %{$MockSNMP::last_var_bind_list}) > 0, 'Response contains data');
};

# TEST SNMP GETNEXT REQUEST HANDLING
subtest 'SNMP GETNEXT request' => sub {
    plan tests => 3;
    
    # Reset mock state
    MockSNMP::reset();
    $MockSNMP::pdu_type = 1; # GETNEXT
    
    my $agent = SNMP::BIND9::Agent->new(
        stats => $stats,
        community => 'public',
        port => 161,
        agent_addr => '127.0.0.1',
    );
    
    # Initialize agent
    $agent->init_agent();
    
    # Trigger the callback that would normally be called by Net::SNMP
    my $session = $agent->{session};
    ok($session->trigger_callback(), 'GETNEXT callback triggered');
    
    # Verify response
    ok(defined $MockSNMP::last_var_bind_list, 'Response was generated');
    ok(scalar(keys %{$MockSNMP::last_var_bind_list}) > 0, 'Response contains data');
};

# ERROR HANDLING TESTS
subtest 'Error handling' => sub {
    plan tests => 3;
    
    # Test with missing required parameters
    eval {
        my $agent = SNMP::BIND9::Agent->new(
            community => 'public',
            port => 161,
        );
    };
    like($@, qr/stats parameter is required/, 'Constructor fails without stats parameter');
    
    # Test with invalid stats object
    eval {
        my $agent = SNMP::BIND9::Agent->new(
            stats => "not an object",
            community => 'public',
            port => 161,
        );
    };
    like($@, qr/must be a valid/, 'Constructor fails with invalid stats object');
    
    # Test error logging
    my $agent = SNMP::BIND9::Agent->new(
        stats => $stats,
        community => 'public',
        port => 161,
    );
    
    # Force an error
    $agent->{errors} = ["Test error"];
    is($agent->last_error(), "Test error", 'last_error returns most recent error');
};

# Clean up
unlink $stats_file;
