# Contributing to SNMP BIND9 Statistics

Thank you for considering contributing to this project! Here are some guidelines to help you get started.

## Code of Conduct

This project adheres to a code of conduct. By participating, you are expected to uphold this code.

## How Can I Contribute?

### Reporting Bugs

- Check if the bug has already been reported in the [Issues](https://github.com/thomasvincent/snmp-bind9-statistics/issues)
- If not, create a new issue with a clear title and description
- Include as much relevant information as possible
- Include steps to reproduce the issue

### Suggesting Enhancements

- Check if the enhancement has already been suggested in the [Issues](https://github.com/thomasvincent/snmp-bind9-statistics/issues)
- If not, create a new issue with a clear title and description
- Explain why this enhancement would be useful

### Pull Requests

1. Fork the repository
2. Create a new branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run the tests to ensure they pass (`prove -r t`)
5. Commit your changes using conventional commit format (`git commit -m 'feat: add some amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## Development Setup

1. Clone the repository
2. Install dependencies:
   ```
   cpanm --installdeps .
   cpanm Test::MockObject Test::MockModule
   ```

## Testing

Run the tests with:

```
prove -r t
```

## Coding Standards

- Follow Perl best practices
- Use Perl::Critic and Perl::Tidy for code quality
- Write tests for new features
- Document your code with POD

## Commit Messages

This project uses the [Conventional Commits](https://www.conventionalcommits.org/) format for commit messages:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

Types include:
- feat: A new feature
- fix: A bug fix
- docs: Documentation only changes
- style: Changes that do not affect the meaning of the code
- refactor: A code change that neither fixes a bug nor adds a feature
- perf: A code change that improves performance
- test: Adding missing tests or correcting existing tests
- chore: Changes to the build process or auxiliary tools

## License

By contributing, you agree that your contributions will be licensed under the project's MIT License.
