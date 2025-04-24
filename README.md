# SNMP BIND9 Statistics

A Perl script for collecting and displaying BIND9 DNS server statistics via SNMP.

## Overview

This tool provides a simple way to monitor BIND9 DNS server performance metrics through SNMP. It collects statistics from the BIND9 server using the `rndc stats` command and makes them available via SNMP, allowing for integration with various monitoring systems.

## Features

- Collects BIND9 statistics using `rndc stats`
- Exposes statistics via SNMP
- Configurable polling intervals
- Supports multiple BIND9 instances
- Comprehensive logging

## Requirements

- Perl 5.10 or higher
- BIND9 DNS Server with `rndc` configured
- Net::SNMP Perl module
- File::Slurp Perl module
- Log::Log4perl Perl module

## Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/snmp-bind9-statistics.git
cd snmp-bind9-statistics

# Install required Perl modules
cpanm Net::SNMP File::Slurp Log::Log4perl
```

## Configuration

Create a configuration file named `config.ini` in the same directory as the script:

```ini
[general]
stats_file = /var/cache/bind/named.stats
log_level = INFO
poll_interval = 300

[snmp]
community = public
port = 161
```

## Usage

```bash
bin/snmp_bind9_stats.pl --config=/path/to/config.ini
```

## Testing

```bash
# Run unit tests
prove -r t/unit

# Run integration tests
prove -r t/integration
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Security

Please see our [Security Policy](SECURITY.md) for details on reporting vulnerabilities.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request
