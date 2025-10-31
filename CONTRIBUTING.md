# Contributing to Cardano RWA

Thank you for your interest in contributing to the Cardano RWA platform! This document provides guidelines and instructions for contributing.

## 📋 Code of Conduct

We are committed to providing a welcoming and inspiring community for all. Please read and adhere to our [Code of Conduct](CODE_OF_CONDUCT.md).

## 🚀 Getting Started

### 1. Fork and Clone

```bash
# Fork the repository on GitHub
git clone https://github.com/YOUR_USERNAME/ADA.git
cd ADA
git remote add upstream https://github.com/Trustiva7777/ADA.git
```

### 2. Setup Development Environment

```bash
# Install dependencies
pnpm install

# Install .NET SDK (if needed)
dotnet restore

# Setup Git hooks
npm run prepare
```

### 3. Create a Feature Branch

```bash
git checkout -b feature/your-feature-name
git checkout -b fix/your-bug-fix
git checkout -b docs/your-documentation
```

## 📝 Development Workflow

### Code Standards

#### TypeScript/JavaScript

```bash
# Format code
pnpm run format

# Lint code
pnpm run lint

# Fix lint issues
pnpm run lint:fix

# Type check
pnpm run type-check
```

#### C#/.NET

```bash
# Format code
dotnet format

# Build
dotnet build

# Run tests
dotnet test
```

### Testing

```bash
# Run all tests
pnpm run test

# Run tests in watch mode
pnpm run test:watch

# Generate coverage report
pnpm run test:coverage
```

### Documentation

```bash
# Build documentation
pnpm run docs:build

# Serve documentation locally
pnpm run docs:serve
```

## 🔄 Commit Guidelines

### Conventional Commits

Use [Conventional Commits](https://www.conventionalcommits.org/) format:

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Commit Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, semicolons, etc.)
- `refactor`: Code refactoring
- `perf`: Performance improvements
- `test`: Test additions/changes
- `chore`: Build, dependencies, tooling

### Examples

```bash
git commit -m "feat(qh-r1): add KYC allowlist gating"
git commit -m "fix(policy): correct time-lock calculation"
git commit -m "docs(setup): update installation instructions"
git commit -m "refactor(distribution): optimize payout calculation"
```

## 📤 Submitting Changes

### Before Creating a Pull Request

1. **Update your branch**
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Run all checks**
   ```bash
   pnpm run lint
   pnpm run type-check
   pnpm run test
   pnpm run build
   ```

3. **Update documentation**
   - Add/update README sections if needed
   - Update API documentation
   - Add CHANGELOG entry

### Creating a Pull Request

1. **Push to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```

2. **Create PR on GitHub**
   - Use descriptive title: `feat: Add KYC allowlist support`
   - Reference related issues: `Closes #123`
   - Include checklist from template

3. **PR Description Template**
   ```markdown
   ## Description
   Brief description of changes

   ## Type of Change
   - [ ] Bug fix
   - [ ] New feature
   - [ ] Breaking change
   - [ ] Documentation update

   ## Related Issues
   Closes #123

   ## Testing
   How to test these changes

   ## Checklist
   - [ ] Code follows style guidelines
   - [ ] Tests added/updated
   - [ ] Documentation updated
   - [ ] No breaking changes
   ```

## 🔍 Code Review Process

### What to Expect

1. **Automated checks**: CI/CD pipeline runs
   - Linting
   - Type checking
   - Tests
   - Build verification

2. **Maintainer review**: 
   - Code quality
   - Security implications
   - Design alignment
   - Performance impact

3. **Community feedback**: Others may comment

### Addressing Review Comments

```bash
# Make changes based on feedback
git add .
git commit -m "chore: address review feedback"
git push origin feature/your-feature-name
# No need to create new PR, it updates automatically
```

## 🚨 Security Issues

**Do NOT** open a public issue for security vulnerabilities. Instead:

1. Email `security@trustiva.io`
2. Include detailed information
3. Allow 90 days for resolution before public disclosure

See [SECURITY.md](SECURITY.md) for complete policy.

## 📚 Documentation Contributions

### Adding Documentation

```bash
# Documentation lives in cardano-rwa-qh/docs/
mkdir -p cardano-rwa-qh/docs/guides
touch cardano-rwa-qh/docs/guides/my-guide.md
```

### Documentation Standards

- Use markdown format
- Include table of contents for longer docs
- Add code examples
- Include diagrams where helpful (Mermaid)
- Update root README if applicable

### Example Documentation

```markdown
# Feature Title

## Overview
Brief description of the feature

## Prerequisites
- List requirements
- Tools needed

## Setup
Step-by-step instructions

## Usage
Examples and common patterns

## Troubleshooting
Common issues and solutions

## References
Links to related docs
```

## 🐛 Bug Reports

### Creating a Bug Report

1. **Check existing issues**: Avoid duplicates
2. **Use bug template**: GitHub will suggest it
3. **Include details**:
   - OS and environment
   - Steps to reproduce
   - Expected behavior
   - Actual behavior
   - Screenshots/logs

### Bug Template

```markdown
## Description
Clear description of the bug

## Steps to Reproduce
1. Step one
2. Step two
3. Step three

## Expected Behavior
What should happen

## Actual Behavior
What actually happens

## Environment
- OS: Windows/Mac/Linux
- Version: 9.0.x
- Node: 18.x or npm version

## Logs
Relevant error messages or logs

## Screenshots
If applicable
```

## ✨ Feature Requests

### Proposing Features

1. **Check discussions**: See if already proposed
2. **Create discussion**: In GitHub Discussions
3. **Proposal template**:

```markdown
## Problem
What problem does this solve?

## Proposed Solution
How would you solve it?

## Alternatives
Other approaches considered

## Implementation
Technical approach overview

## Examples
How would it be used?
```

## 📦 Release Process

### Version Numbers

We follow [Semantic Versioning](https://semver.org/):
- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes

### Release Steps

1. Create release branch: `release/v1.2.3`
2. Update version numbers
3. Update CHANGELOG
4. Merge to main
5. Tag release: `v1.2.3`
6. Publish to npm/NuGet

## 🏆 Recognition

### Contributors

All contributors are recognized in:
- CONTRIBUTORS.md file
- GitHub contributors page
- Release notes

### Levels of Contribution

- **Core Team**: Regular commits, design decisions
- **Contributors**: Features, fixes, documentation
- **Community**: Bug reports, feedback, usage

## 📞 Questions?

- **GitHub Issues**: For bugs and features
- **GitHub Discussions**: For questions and ideas
- **Email**: dev@trustiva.io
- **Discord**: Join our community server

## 📚 Additional Resources

- [Conventional Commits](https://www.conventionalcommits.org/)
- [Keep a Changelog](https://keepachangelog.com/)
- [Git Documentation](https://git-scm.com/doc)
- [Cardano Developer Hub](https://developers.cardano.org/)
- [TypeScript Best Practices](https://www.typescriptlang.org/docs/handbook/)

## 📄 License

By contributing to Cardano RWA, you agree that your contributions will be licensed under the MIT License.

---

**Thank you for contributing!** 🎉

