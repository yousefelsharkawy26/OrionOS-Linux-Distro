# OrionOS Developer Guide

## Getting Started

### Prerequisites

- Arch Linux or Arch-based distribution
- 50GB free disk space
- Internet connection
- `base-devel` package group

### Repository Structure

```
orionos/
├── packages/          # Package definitions (PKGBUILDs)
│   ├── core/         # Core system packages
│   ├── extra/        # Additional packages
│   └── community/    # Community packages
├── kernel/           # Custom kernel build
│   ├── config/       # Kernel configurations
│   └── Makefile      # Kernel build system
├── scripts/          # Build and utility scripts
│   └── build/        # Build system scripts
├── ci/               # CI/CD configuration
│   └── github-actions/
├── testing/          # Test suite
└── docs/             # Documentation
```

### Setting Up Development Environment

```bash
# Clone the repository
git clone https://github.com/yousefelsharkawy26/OrionOS-Linux-Distro.git
cd OrionOS-Linux-Distro

# Initialize build environment
make init

# Verify setup
make test
```

## Building

### Build Everything

```bash
make all
```

### Build Specific Components

```bash
make kernel          # Build custom kernel
make packages        # Build packages
make iso            # Generate ISO image
make repo           # Create package repository
```

### Build Profiles

```bash
make PROFILE=gaming all      # Gaming-optimized build
make PROFILE=developer all   # Developer tools included
make PROFILE=minimal all     # Minimal installation
```

## Package Development

### Creating a New Package

1. Create a new directory under `packages/core/`, `packages/extra/`, or `packages/community/`
2. Write a `PKGBUILD` file following Arch Linux packaging standards
3. Test the package build: `cd <package-dir> && makepkg -s`

### Package Guidelines

- All packages must include proper `pkgname`, `pkgver`, `pkgrel`, `pkgdesc`, `arch`, `url`, `license`
- Dependencies must be accurate and minimal
- Use `backup` array for configuration files
- Include `install` scripts for services that need enabling
- Follow the existing package structure for consistency

## Testing

### Running Tests

```bash
# Run all tests
make test

# Run specific test suites
./testing/run-tests.sh
```

### Writing Tests

Add test functions to `testing/run-tests.sh` following the existing pattern:

```bash
test_my_feature() {
    local test_name="My Feature Test"
    ((TOTAL_TESTS++))

    if [[ some_condition ]]; then
        log_pass "$test_name"
    else
        log_fail "$test_name - description of failure"
    fi
}
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Make your changes
4. Run tests (`make test`)
5. Commit with descriptive messages
6. Push to your fork
7. Create a Pull Request

### Commit Message Format

```
component: Brief description

Longer explanation if needed, describing what changed and why.

- Bullet points for multiple changes
- Reference issues: Fixes #123
```

## Debugging

### Build Logs

Build logs are stored in `build/logs/` with timestamps.

### Verbose Output

Set `ORIONOS_LOG_LEVEL=DEBUG` for verbose output:

```bash
ORIONOS_LOG_LEVEL=DEBUG make all
```

### Common Issues

| Issue | Solution |
|-------|----------|
| Missing dependencies | Run `make init` to install build deps |
| GPG key errors | Set `GPG_KEY` environment variable |
| Permission denied | Ensure you're in the `wheel` group |
| Out of disk space | Clean with `make clean` or `make distclean` |
