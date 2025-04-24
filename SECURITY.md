# Security Policy

## Supported Versions

The following versions of SNMP BIND9 Statistics are currently being supported with security updates:

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

We take the security of the SNMP BIND9 Statistics code seriously. If you believe you've found a security vulnerability, please follow these guidelines:

1. **Do not disclose the vulnerability publicly** - Please do not create a public GitHub issue for security vulnerabilities.

2. **Email the maintainer directly** - Send a description of the issue to thomasvincent@example.com.

3. **Include details** - In your report, please include:
   - A clear description of the vulnerability
   - Steps to reproduce the issue
   - Potential impact of the vulnerability
   - Any possible mitigations you've identified

4. **Allow time for response** - The maintainer will acknowledge your email within 48 hours and provide an estimated timeline for a fix.

## What to Expect

After reporting a vulnerability:

1. You will receive an acknowledgment of your report within 48 hours.
2. The maintainer will investigate and determine the potential impact.
3. A fix will be developed and tested.
4. A new version will be released with the security fix.
5. After the fix is released, the vulnerability will be publicly disclosed (if appropriate).

## Security Best Practices for Deployment

When deploying SNMP BIND9 Statistics, consider these security best practices:

1. Run the agent with minimal privileges
2. Use a non-default SNMP community string
3. Restrict access to the SNMP port using firewall rules
4. Use SNMPv3 when possible for authenticated and encrypted communications
5. Regularly update to the latest version

Thank you for helping to keep SNMP BIND9 Statistics secure!

# Security Policy

We take security seriously. If you discover any security related issues, please email security@example.com instead of using the issue tracker.

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

Please report (suspected) security vulnerabilities to security@example.com. You will receive a response from us within 48 hours. If the issue is confirmed, we will release a patch as soon as possible depending on complexity but historically within 7 days.

## Additional Security Considerations

### SNMP Security
- Always use SNMPv3 with authentication and encryption in production environments
- Restrict SNMP access to trusted hosts only
- Use strong community strings if using SNMPv2c
- Regularly rotate community strings and credentials

### Perl-specific Security
- Keep all Perl modules updated to their latest versions
- Validate all input data, especially when parsing configuration files
- Use taint mode (`-T`) when running scripts that process external input
- Follow the principle of least privilege when executing system commands

### BIND9 Security
- Keep BIND9 updated to the latest stable version
- Use TSIG for securing zone transfers
- Implement proper access controls in your BIND9 configuration
- Consider using DNSSEC for DNS integrity
