# OrionOS Contribution Guide

## Welcome

Thank you for your interest in contributing to OrionOS! This guide will help you get started with contributing to the project.

## Table of Contents

1. [Getting Started](#getting-started)
2. [Types of Contributions](#types-of-contributions)
3. [Development Workflow](#development-workflow)
4. [Coding Standards](#coding-standards)
5. [Submitting Changes](#submitting-changes)
6. [Review Process](#review-process)
7. [Community](#community)

## Getting Started

### Prerequisites

- Git
- GitHub account
- Arch Linux (or container)
- Basic knowledge of:
  - Shell scripting
  - Python
  - Linux system administration

### Fork and Clone

```bash
# Fork the repository on GitHub
# Then clone your fork:
git clone https://github.com/YOUR-USERNAME/orionos.git
cd orionos

# Add upstream remote
git remote add upstream https://github.com/orionos/orionos.git
```

### Development Setup

```bash
# Initialize build environment
make init

# Install development dependencies
sudo pacman -S --needed base-devel git archiso python python-pytest
```

## Types of Contributions

### Code Contributions

- **Packages**: New packages or package updates
- **Kernel**: Kernel configuration changes or patches
- **Services**: System services and daemons
- **Desktop**: Desktop environment components
- **AI**: AI platform features or integrations
- **Gaming**: Gaming optimizations or configurations
- **Security**: Security features or hardening

### Documentation

- User guides
- Developer documentation
- Man pages
- Comments and docstrings

### Testing

- Unit tests
- Integration tests
- Performance benchmarks
- Manual testing

### Design

- Visual assets (icons, wallpapers)
- UI/UX improvements
- Theme updates

### Translations

- UI translations
- Documentation translations

## Development Workflow

### Branch Naming

```
feature/description     # New features
fix/description         # Bug fixes
docs/description        # Documentation
refactor/description    # Code refactoring
test/description        # Test changes
chore/description       # Maintenance
```

### Example Workflow

```bash
# Sync with upstream
git checkout main
git pull upstream main

# Create feature branch
git checkout -b feature/my-feature

# Make changes
# ... edit files ...

# Test changes
make test

# Commit
git add .
git commit -m "feat: add new feature

Detailed description of what and why.

- Change 1
- Change 2

Closes #123"

# Push
git push origin feature/my-feature

# Create Pull Request on GitHub
```

### Commit Messages

Format:
```
type(scope): subject

body

footer
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `style`: Formatting
- `refactor`: Code restructuring
- `test`: Tests
- `chore`: Build/tools

**Scopes:**
- `kernel`: Kernel changes
- `pkg`: Package changes
- `desktop`: Desktop environment
- `ai`: AI platform
- `gaming`: Gaming stack
- `security`: Security features
- `docs`: Documentation
- `ci`: CI/CD

**Example:**
```
feat(gaming): add auto-optimization for Elden Ring

Implement game-specific profile for Elden Ring including:
- Custom launch options
- Environment variables
- CPU priority settings

Tested on:
- NVIDIA RTX 3070
- AMD RX 6700 XT

Closes #456
```

## Coding Standards

### Shell Scripts

```bash
#!/bin/bash
set -euo pipefail

# Functions
my_function() {
    local param="$1"
    local output

    output=$(command "$param")
    echo "$output"
}

# Main
main() {
    my_function "$@"
}

main "$@"
```

### Python

```python
#!/usr/bin/env python3
"""Module docstring."""

import logging
from pathlib import Path
from typing import Optional

logger = logging.getLogger(__name__)

def my_function(param: str) -> Optional[str]:
    """Function docstring."""
    if not param:
        return None
    return param.upper()
```

### PKGBUILD

```bash
# Maintainer: Name <email@orionos.org>
pkgname=my-package
pkgver=1.0.0
pkgrel=1
pkgdesc="Clear description"
arch=('x86_64')
url="https://example.com"
license=('MIT')
depends=('dep1' 'dep2')
source=("$url/$pkgname-$pkgver.tar.gz")
sha256sums=('SKIP')

build() {
    cd "$pkgname-$pkgver"
    ./configure --prefix=/usr
    make
}

package() {
    cd "$pkgname-$pkgver"
    make DESTDIR="$pkgdir" install
}
```

## Submitting Changes

### Pull Request Checklist

Before submitting:

- [ ] Code follows style guidelines
- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] Commit messages follow format
- [ ] Rebased on latest main
- [ ] No merge conflicts

### Pull Request Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation
- [ ] Refactoring

## Testing
How was this tested?

## Checklist
- [ ] Code follows style
- [ ] Tests added
- [ ] Docs updated

## Related Issues
Fixes #123
```

## Review Process

### For Contributors

1. Submit PR with clear description
2. Respond to review comments
3. Make requested changes
4. Re-request review when ready
5. Maintain clean commit history

### For Reviewers

1. Check code quality
2. Verify tests pass
3. Review documentation
4. Test locally if needed
5. Approve or request changes

### Review Criteria

| Aspect | Check |
|--------|-------|
| Functionality | Works as intended |
| Code Quality | Clean, maintainable |
| Tests | Adequate coverage |
| Documentation | Clear and complete |
| Security | No vulnerabilities |
| Performance | No regressions |

## Community

### Communication Channels

- **Discord**: [discord.gg/orionos](https://discord.gg/orionos)
- **Forum**: [forum.orionos.org](https://forum.orionos.org)
- **Matrix**: #orionos:matrix.org

### Getting Help

- Check documentation first
- Search existing issues
- Ask in Discord #help channel
- Open issue if needed

### Code of Conduct

- Be respectful
- Welcome newcomers
- Accept constructive criticism
- Focus on what's best for the community

## Areas Needing Help

### Good First Issues

- Documentation improvements
- Test coverage
- Bug fixes
- Translations

### High Priority

- Hardware support
- Performance optimizations
- Security hardening
- User experience

### Advanced

- Kernel development
- AI model integration
- Graphics drivers
- Network stack

## Recognition

Contributors will be:
- Listed in CONTRIBUTORS.md
- Mentioned in release notes
- Credited in relevant documentation

## Questions?

Contact:
- Discord: #development channel
- Email: dev@orionos.org

Thank you for contributing to OrionOS!
