# OrionOS Developer Guide

## Table of Contents

1. [Getting Started](#getting-started)
2. [Development Environment](#development-environment)
3. [Build System](#build-system)
4. [Package Development](#package-development)
5. [Kernel Development](#kernel-development)
6. [Service Development](#service-development)
7. [AI Plugin Development](#ai-plugin-development)
8. [Testing](#testing)
9. [Contribution Workflow](#contribution-workflow)
10. [Coding Standards](#coding-standards)

## Getting Started

### Prerequisites

- Arch Linux (or derivative) installed
- `base-devel` package group
- Git configured with your identity
- Basic knowledge of:
  - Shell scripting (Bash)
  - Python 3
  - systemd services
  - PKGBUILD format

### Clone Repository

```bash
git clone https://github.com/orionos/orionos.git
cd orionos
```

### Development Branches

| Branch | Purpose |
|--------|---------|
| `main` | Stable releases |
| `develop` | Active development |
| `feature/*` | Feature branches |
| `release/*` | Release preparation |
| `hotfix/*` | Critical fixes |

## Development Environment

### Install Development Dependencies

```bash
# Core tools
sudo pacman -S --needed base-devel git archiso

# Python tools
sudo pacman -S --needed python python-pip python-virtualenv
pip install --user pytest black flake8 pylint mypy

# Documentation tools
sudo pacman -S --needed mkdocs mkdocs-material

# Container tools (optional)
sudo pacman -S --needed docker podman
```

### Setup Development Environment

```bash
# Run setup script
./scripts/dev/setup-env.sh

# Or manually:
mkdir -p build/{iso,packages,kernel,repo,logs}
mkdir -p .cache
```

### IDE Configuration

#### VS Code Extensions (Recommended)

- Python
- ShellCheck
- EditorConfig
- markdownlint
- YAML
- TOML

#### EditorConfig

The project includes `.editorconfig`:

```ini
root = true

[*]
indent_style = space
indent_size = 4
end_of_line = lf
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true

[*.{yml,yaml}]
indent_size = 2

[*.{sh,bash}]
indent_style = tab

[*.md]
trim_trailing_whitespace = false
```

## Build System

### Makefile Targets

| Target | Description | Dependencies |
|--------|-------------|--------------|
| `all` | Full build | `repo`, `kernel`, `packages`, `iso` |
| `init` | Initialize environment | None |
| `kernel` | Build custom kernel | `init` |
| `packages` | Build all packages | `init` |
| `repo` | Create package repository | `packages` |
| `iso` | Generate ISO image | `kernel`, `repo` |
| `test` | Run test suite | None |
| `clean` | Clean build artifacts | None |
| `distclean` | Deep clean | `clean` |

### Build Profiles

```bash
# Default profile (balanced desktop)
make all PROFILE=default

# Gaming profile
make all PROFILE=gaming

# Developer profile
make all PROFILE=developer

# Minimal profile
make all PROFILE=minimal
```

### Custom Build Flags

```bash
# Parallel jobs
make all JOBS=8

# Custom version
make all VERSION=0.2.0-custom

# Verbose output
make all V=1
```

## Package Development

### Creating a New Package

1. Create package directory:

```bash
mkdir -p packages/core/my-package
cd packages/core/my-package
```

2. Create PKGBUILD:

```bash
# Maintainer: Your Name <your.email@orionos.org>
pkgname=my-package
pkgver=1.0.0
pkgrel=1
pkgdesc="Description of your package"
arch=('x86_64')
url="https://example.com"
license=('MIT')
depends=('dependency1' 'dependency2')
optdepends=('optional-dep: for additional feature')
source=("https://example.com/$pkgname-$pkgver.tar.gz")
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

3. Build and test:

```bash
makepkg -si
```

### Package Guidelines

- Follow [Arch Packaging Standards](https://wiki.archlinux.org/title/Arch_packaging_standards)
- Include proper `pkgdesc` with clear description
- Set appropriate `license`
- List all dependencies in `depends`
- Use `optdepends` for optional features
- Include changelog if applicable

### Package Categories

| Directory | Purpose |
|-----------|---------|
| `packages/core/` | Essential system components |
| `packages/extra/` | Desktop environment and tools |
| `packages/community/` | Additional software |

## Kernel Development

### Kernel Configuration

Edit `kernel/config/orionos-kernel.config`:

```bash
# Using menuconfig
cd kernel
make extract
make config
cd sources/linux-*
make menuconfig
# Save to orionos-kernel.config
cp .config ../../config/orionos-kernel.config
```

### Adding Kernel Patches

1. Place patch in `kernel/patches/`:

```bash
# Category directories
kernel/patches/cachyos/       # CachyOS patches
kernel/patches/gaming/        # Gaming patches
kernel/patches/desktop/       # Desktop patches
kernel/patches/security/      # Security patches
```

2. Patches are applied in numerical order:

```
0001-feature-name.patch
0002-another-feature.patch
```

3. Test patch application:

```bash
cd kernel
make extract
make patch
```

### Creating Custom Patches

```bash
cd kernel/sources/linux-*
# Make your changes
git diff > ../../patches/custom/0001-my-feature.patch
```

## Service Development

### Creating a systemd Service

1. Create service file:

```ini
# /usr/lib/systemd/system/my-service.service
[Unit]
Description=My OrionOS Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/my-service
Restart=on-failure
RestartSec=5
User=nobody
Group=nobody

# Security hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true

[Install]
WantedBy=multi-user.target
```

2. Service implementation:

```python
#!/usr/bin/env python3
"""
OrionOS My Service
Description of what this service does.
"""

import logging
import signal
import sys
import time

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('my-service')

class MyService:
    def __init__(self):
        self._running = False

    def start(self):
        self._running = True
        logger.info("Service started")

        while self._running:
            # Service logic here
            time.sleep(1)

    def stop(self):
        self._running = False
        logger.info("Service stopped")

def main():
    service = MyService()

    def signal_handler(signum, frame):
        service.stop()
        sys.exit(0)

    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)

    service.start()

if __name__ == '__main__':
    main()
```

### Service Best Practices

- Use `Type=notify` for services that call `sd_notify()`
- Always set `Restart=on-failure`
- Apply security hardening options
- Use proper logging with journald
- Handle SIGTERM gracefully
- Store state in `/var/lib/orionos/`
- Store cache in `/var/cache/orionos/`

## AI Plugin Development

### Creating an AI Plugin

```python
# /usr/share/orionos/ai/plugins/my-plugin.py

class OrionOSPlugin:
    """My AI Plugin for OrionOS"""

    version = "1.0.0"
    description = "Description of my plugin"

    def __init__(self):
        self.manager = None

    def register(self, plugin_manager):
        """Register with the plugin manager"""
        self.manager = plugin_manager

        # Register hooks
        plugin_manager.register_hook("model_loaded", self.on_model_loaded)
        plugin_manager.register_hook("chat_request", self.on_chat_request)

    def on_model_loaded(self, model_name):
        """Called when a model is loaded"""
        print(f"Plugin: Model {model_name} loaded")

    def on_chat_request(self, messages):
        """Called on chat requests - can modify messages"""
        # Add system context
        messages.insert(0, {
            "role": "system",
            "content": "Additional context from my plugin."
        })
        return messages

    def cleanup(self):
        """Cleanup when plugin is unloaded"""
        pass
```

### Plugin Hooks

| Hook | Description | Parameters |
|------|-------------|------------|
| `model_loaded` | Model loaded | `model_name` |
| `model_unloaded` | Model unloaded | `model_name` |
| `chat_request` | Chat request | `messages` |
| `chat_response` | Chat response | `response` |
| `voice_input` | Voice input | `audio_data` |
| `voice_output` | Voice output | `text` |

## Testing

### Running Tests

```bash
# Run all tests
./testing/run-tests.sh

# Run specific test suites
./testing/run-tests.sh unit
./testing/run-tests.sh integration
./testing/run-tests.sh security
./testing/run-tests.sh performance

# Run with verbose output
DEBUG=1 ./testing/run-tests.sh
```

### Writing Tests

```bash
#!/bin/bash
# testing/unit/test-my-feature.sh

source "${BASH_SOURCE%/*}/../test-lib.sh"

test_my_feature() {
    # Setup
    local temp_dir=$(mktemp -d)

    # Test
    result=$(my-feature --test)
    assert_equals "$result" "expected_output" "Feature should return correct value"

    # Cleanup
    rm -rf "$temp_dir"
}

# Run test
run_test "test_my_feature"
```

### Test Categories

| Directory | Purpose | Examples |
|-----------|---------|----------|
| `testing/unit/` | Unit tests | PKGBUILD syntax, config validation |
| `testing/integration/` | Integration tests | Package builds, service startup |
| `testing/security/` | Security tests | Policy validation, permission checks |
| `testing/performance/` | Performance tests | Benchmarks, resource usage |

## Contribution Workflow

1. **Fork and Branch**

```bash
git clone https://github.com/YOUR-USERNAME/orionos.git
cd orionos
git checkout -b feature/my-feature
```

2. **Make Changes**

- Follow coding standards
- Add tests for new features
- Update documentation

3. **Test**

```bash
# Run linting
make lint

# Run tests
make test

# Build packages
make packages
```

4. **Commit**

```bash
git add .
git commit -m "feat: add new feature description

Detailed description of the change.

- Bullet points for changes
- Reference issues: #123"
```

5. **Submit Pull Request**

- Use descriptive title
- Reference related issues
- Include test results
- Add screenshots if UI changes

### Commit Message Format

```
type(scope): subject

body

footer
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes
- `refactor`: Code refactoring
- `test`: Test changes
- `chore`: Build/dependency changes

**Examples:**
```
feat(kernel): add BORE scheduler patch

Implements the BORE (Burst-Oriented Response Enhancer) scheduler
for better desktop interactivity.

- Adds 0001-bore-scheduler.patch
- Configures scheduler options
- Updates documentation

Closes #42
```

## Coding Standards

### Shell Scripts

- Use Bash for all scripts (`#!/bin/bash`)
- Enable strict mode: `set -euo pipefail`
- Use `[[ ]]` for conditionals
- Quote all variables: `"$variable"`
- Use functions for reusable code
- Add error handling
- Document with comments

```bash
#!/bin/bash
set -euo pipefail

# Description of function
my_function() {
    local param="$1"
    local output

    output=$(some_command "$param")

    if [[ $? -eq 0 ]]; then
        echo "$output"
    else
        echo "Error: command failed" >&2
        return 1
    fi
}
```

### Python Code

- Follow PEP 8
- Use type hints
- Document with docstrings
- Handle exceptions properly
- Use logging instead of print

```python
"""
Module docstring describing the module.
"""

import logging
from pathlib import Path
from typing import Optional

logger = logging.getLogger(__name__)

def my_function(param: str) -> Optional[str]:
    """
    Function description.

    Args:
        param: Description of parameter

    Returns:
        Description of return value, or None if error

    Raises:
        ValueError: If param is invalid
    """
    if not param:
        raise ValueError("param cannot be empty")

    try:
        result = process(param)
        return result
    except Exception as e:
        logger.error(f"Processing failed: {e}")
        return None
```

### Configuration Files

- Use consistent indentation
- Add comments for non-obvious settings
- Group related settings together
- Use descriptive names

## Debugging

### Enable Debug Logging

```bash
export DEBUG=1
make all
```

### View Service Logs

```bash
# System service
journalctl -u orionos-performance -f

# User service
journalctl --user -u orionos-gaming -f
```

### Build Troubleshooting

```bash
# Clean build
make distclean

# Verbose build
make all V=1

# Check logs
cat build/logs/*.log
```

## Resources

- [Arch Wiki - PKGBUILD](https://wiki.archlinux.org/title/PKGBUILD)
- [Arch Wiki - Creating Packages](https://wiki.archlinux.org/title/Creating_packages)
- [systemd Service Documentation](https://www.freedesktop.org/software/systemd/man/systemd.service.html)
- [Hyprland Configuration](https://wiki.hyprland.org/Configuring/)
- [Kernel Documentation](https://www.kernel.org/doc/html/latest/)

## Getting Help

- **Discord**: [discord.gg/orionos](https://discord.gg/orionos)
- **Forum**: [forum.orionos.org](https://forum.orionos.org)
- **Matrix**: #orionos-dev:matrix.org
- **Issues**: [GitHub Issues](https://github.com/orionos/orionos/issues)
