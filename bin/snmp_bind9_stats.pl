#!/usr/bin/env perl

use strict;
use warnings;
use 5.010;
use Getopt::Long;
use Pod::Usage;
use Config::IniFiles;
use Net::SNMP qw(:snmp);
use File::Slurp qw(read_file);
use Log::Log4perl qw(:easy);
use FindBin qw($Bin);
use lib "$Bin/../lib";
use SNMP::BIND9::Statistics;
use SNMP::BIND9::Agent;
use POSIX qw(strftime);
use Time::HiRes qw(sleep);
use Scalar::Util qw(blessed);
use sigtrap qw(handler sig_handler normal-signals);

# Version
our $VERSION = '1.0.0';

# Initialize logging
sub init_logging {
    my $log_level = shift || 'INFO';
    my $log_conf = qq{
        log4perl.rootLogger=$log_level, SCREEN
        log4perl.appender.SCREEN=Log::Log4perl::Appender::Screen
        log4perl.appender.SCREEN.layout=PatternLayout
        log4perl.appender.SCREEN.layout.ConversionPattern=[%d] [%p] %m%n
    };
    Log::Log4perl->init(\$log_conf);
}

# Parse command line options
sub parse_options {
    my %opts;
    GetOptions(
        'config=s'  => \$opts{config},
        'help|?'    => \$opts{help},
        'man'       => \$opts{man},
        'version'   => \$opts{version},
    ) or pod2usage(2);

    if ($opts{help}) {
        pod2usage(1);
    }
    if ($opts{man}) {
        pod2usage(-exitval => 0, -verbose => 2);
    }
    if ($opts{version}) {
        say "snmp_bind9_stats.pl version $VERSION";
        exit 0;
    }

    # Default config file location
    $opts{config} ||= "$Bin/../config.ini";
    
    return \%opts;
}

# Load configuration
sub load_config {
    my $config_file = shift;
    
    unless (-e $config_file) {
        ERROR("Config file not found: $config_file");
        exit 1;
    }
    
    my $cfg = Config::IniFiles->new(-file => $config_file);
    unless ($cfg) {
        ERROR("Failed to parse config file: " . join("\n", @Config::IniFiles::errors));
        exit 1;
    }
    
    return $cfg;
}

# Global agent reference for signal handler
our $AGENT;

# Signal handler for graceful shutdown
sub sig_handler {
    my $sig = shift;
    INFO("Received signal $sig, shutting down gracefully...");
    
    if ($AGENT && blessed($AGENT) && $AGENT->can('stop')) {
        $AGENT->stop();
        INFO("SNMP BIND9 Statistics Agent stopped");
    }
    
    exit 0;
}

# Main function
sub main {
    my $opts = parse_options();
    my $cfg = load_config($opts->{config});
    
    # Initialize logging with configured level
    my $log_level = $cfg->val('general', 'log_level', 'INFO');
    init_logging($log_level);
    
    INFO("Starting SNMP BIND9 Statistics Agent v$VERSION");
    
    # Create statistics collector
    my $stats;
    eval {
        $stats = SNMP::BIND9::Statistics->new(
            stats_file    => $cfg->val('general', 'stats_file', '/var/cache/bind/named.stats'),
            rndc_command  => $cfg->val('general', 'rndc_command', 'rndc stats'),
            poll_interval => $cfg->val('general', 'poll_interval', 300),
        );
    };
    if ($@) {
        ERROR("Failed to initialize statistics collector: $@");
        exit 1;
    }
    
    unless ($stats) {
        ERROR("Failed to initialize statistics collector");
        exit 1;
    }
    
    # Create SNMP agent
    eval {
        $AGENT = SNMP::BIND9::Agent->new(
            community  => $cfg->val('snmp', 'community', 'public'),
            port       => $cfg->val('snmp', 'port', 161),
            agent_addr => $cfg->val('snmp', 'agent_addr', '0.0.0.0'),
            stats      => $stats,
        );
    };
    if ($@) {
        ERROR("Failed to initialize SNMP agent: $@");
        exit 1;
    }
    
    unless ($AGENT) {
        ERROR("Failed to initialize SNMP agent");
        exit 1;
    }
    
    # Start the agent
    INFO("Starting SNMP agent on " . $cfg->val('snmp', 'agent_addr', '0.0.0.0') . ":" . $cfg->val('snmp', 'port', 161));
    
    eval {
        $AGENT->run();
    };
    if ($@) {
        ERROR("Error running SNMP agent: $@");
        exit 1;
    }
    
    # Infinite loop to keep the script running
    # Signal handlers will catch SIGINT and SIGTERM for shutdown
    while (1) {
        eval {
            # Force statistics update every poll interval
            $stats->collect_stats(1);
            DEBUG("Updated statistics");
        };
        if ($@) {
            WARN("Error collecting statistics: $@");
        }
        
        sleep($cfg->val('general', 'poll_interval', 300));
    }
    
    # We should never reach here due to the signal handlers,
    # but just in case:
    INFO("SNMP BIND9 Statistics Agent stopped");
}

# Run the main function
main();

__END__

=head1 NAME

snmp_bind9_stats.pl - BIND9 DNS server statistics via SNMP

=head1 SYNOPSIS

snmp_bind9_stats.pl [options]

 Options:
   --config=FILE    Path to configuration file
   --help           Brief help message
   --man            Full documentation
   --version        Show version

=head1 DESCRIPTION

This script collects statistics from a BIND9 DNS server using the 'rndc stats'
command and makes them available via SNMP.

=head1 OPTIONS

=over 8

=item B<--config>=FILE

Path to the configuration file. Default is '../config.ini' relative to the script.

=item B<--help>

Print a brief help message and exit.

=item B<--man>

Print the manual page and exit.

=item B<--version>

Print version information and exit.

=back

=head1 CONFIGURATION

The configuration file uses INI format with the following sections and options:

 [general]
 stats_file = /var/cache/bind/named.stats
 rndc_command = rndc stats
 log_level = INFO
 poll_interval = 300

 [snmp]
 community = public
 port = 161

=head1 AUTHOR

Thomas Vincent

=head1 LICENSE

This is released under the MIT License. See the LICENSE file for details.

=cut
