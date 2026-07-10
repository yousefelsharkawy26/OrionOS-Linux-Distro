# OrionOS Release Process

## Overview

OrionOS follows a structured release process to ensure quality and stability. Releases are automated through CI/CD with manual verification gates.

## Release Cycle

```
Development → Testing → Staging → Release → Maintenance
     ↑                                        ↓
     └────────── Next Cycle ←─────────────────┘
```

### Release Types

| Type | Frequency | Example | Purpose |
|------|-----------|---------|---------|
| Nightly | Daily | 0.2.0-nightly.20240101 | Development testing |
| Alpha | Bi-weekly | 0.2.0-alpha.1 | Feature preview |
| Beta | Monthly | 0.2.0-beta.1 | Pre-release testing |
| RC | As needed | 0.2.0-rc.1 | Release candidate |
| Stable | Quarterly | 0.2.0 | Production release |
| LTS | Annually | 1.0.0 | Long-term support |

## Version Numbering

OrionOS uses Semantic Versioning:

```
MAJOR.MINOR.PATCH[-prerelease][+build]

Examples:
0.1.0           # Initial release
0.2.0-alpha.1   # Alpha pre-release
0.2.0-beta.2    # Second beta
0.2.0-rc.1      # Release candidate
0.2.0           # Stable release
1.0.0           # Major release
```

### Version Meaning

- **MAJOR**: Breaking changes, major new features
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes, security updates
- **prerelease**: alpha, beta, rc
- **build**: Build metadata

## Release Branches

```
main
 │
 ├── develop
 │   │
 │   ├── feature/xyz
 │   │
 │   └── release/0.2.0
 │       │
 │       ├── 0.2.0-alpha.1
 │       ├── 0.2.0-alpha.2
 │       ├── 0.2.0-beta.1
 │       ├── 0.2.0-rc.1
 │       └── 0.2.0 (tag)
 │
 └── hotfix/0.1.1
     └── 0.1.1 (tag)
```

## Release Checklist

### Pre-Release

- [ ] All features implemented
- [ ] Tests passing
- [ ] Documentation updated
- [ ] Changelog updated
- [ ] Security scan clean
- [ ] Performance benchmarks acceptable

### Alpha Release

- [ ] Feature freeze for major features
- [ ] Basic testing complete
- [ ] Known issues documented
- [ ] Release notes drafted

### Beta Release

- [ ] All features complete
- [ ] Integration testing passed
- [ ] User documentation complete
- [ ] Upgrade path tested

### RC Release

- [ ] All tests passing
- [ ] No known critical bugs
- [ ] Release notes finalized
- [ ] Sign-off from maintainers

### Stable Release

- [ ] RC testing successful
- [ ] All blockers resolved
- [ ] Release artifacts built
- [ ] Announcement prepared

## Automated Release Process

### CI/CD Pipeline

```yaml
# Trigger: push to release/* branch or version tag

1. Code Quality
   - Lint checks
   - Security scan
   - License check

2. Build
   - Kernel
   - Packages
   - ISO

3. Test
   - Unit tests
   - Integration tests
   - Performance tests

4. Sign
   - Sign packages
   - Sign ISO
   - Generate checksums

5. Release
   - Create GitHub release
   - Upload artifacts
   - Update repository
   - Publish announcement
```

### GitHub Actions Workflow

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build ISO
        run: make iso PROFILE=${{ matrix.profile }}

      - name: Sign artifacts
        run: |
          gpg --detach-sign *.iso
          sha256sum *.iso > SHA256SUMS

      - name: Create release
        uses: softprops/action-gh-release@v1
        with:
          files: |
            *.iso
            *.iso.sig
            SHA256SUMS
          body_path: RELEASE_NOTES.md
```

## Manual Release Steps

### 1. Prepare Release Branch

```bash
# Create release branch
git checkout develop
git pull origin develop
git checkout -b release/0.2.0

# Update version
sed -i 's/VERSION=.*/VERSION=0.2.0/' VERSION

# Update changelog
vim CHANGELOG.md

# Commit
git add .
git commit -m "chore(release): prepare 0.2.0"
git push origin release/0.2.0
```

### 2. Build and Test

```bash
# Build all profiles
make PROFILE=default all
make PROFILE=gaming all
make PROFILE=developer all

# Run tests
make test

# Sign packages
gpg --detach-sign build/iso/*.iso
```

### 3. Create Release

```bash
# Tag release
git tag -a v0.2.0 -m "OrionOS 0.2.0"
git push origin v0.2.0

# GitHub Actions will automatically:
# - Build ISOs
# - Run tests
# - Create release
# - Upload artifacts
```

### 4. Post-Release

```bash
# Merge to main
git checkout main
git merge release/0.2.0
git push origin main

# Merge back to develop
git checkout develop
git merge main
git push origin develop

# Delete release branch
git branch -d release/0.2.0
git push origin --delete release/0.2.0
```

## Release Artifacts

### ISO Images

| Profile | Filename | Size |
|---------|----------|------|
| Default | orionos-0.2.0-default-x86_64.iso | ~2.5GB |
| Gaming | orionos-0.2.0-gaming-x86_64.iso | ~3.5GB |
| Developer | orionos-0.2.0-developer-x86_64.iso | ~4GB |

### Packages

```
orionos-desktop-0.2.0-1-x86_64.pkg.tar.zst
orionos-config-0.2.0-1-any.pkg.tar.zst
orionos-services-0.2.0-1-any.pkg.tar.zst
orionos-themes-0.2.0-1-any.pkg.tar.zst
orionos-security-0.2.0-1-any.pkg.tar.zst
orionos-utils-0.2.0-1-any.pkg.tar.zst
linux-orionos-6.11.0-1-x86_64.pkg.tar.zst
```

### Checksums

```
SHA256SUMS
MD5SUMS
SHA256SUMS.sig
```

## Changelog Format

```markdown
# Changelog

## [0.2.0] - 2024-01-15

### Added
- New AI model support (DeepSeek, Granite)
- Phone sync feature
- HDR gaming improvements
- Night mode scheduling

### Changed
- Updated kernel to 6.11.2
- Improved BORE scheduler tuning
- Enhanced gaming auto-optimization

### Fixed
- Memory leak in AI service
- Bluetooth connection stability
- Multi-monitor wallpaper alignment

### Security
- Updated firewalld rules
- Fixed AppArmor profile for AI service
- Added USBGuard default policy

## [0.1.0] - 2023-12-01

### Added
- Initial release
- ...
```

## Announcement Template

```markdown
# OrionOS 0.2.0 Released

We're excited to announce OrionOS 0.2.0!

## Highlights

✨ **New Features**
- Phone sync with Android/iOS
- AI model marketplace
- HDR gaming support

🔧 **Improvements**
- 15% better gaming performance
- Reduced memory usage
- Faster boot times

🔒 **Security**
- Enhanced firewall rules
- Updated AppArmor profiles
- TPM auto-setup

## Downloads

- [Default ISO](link) - 2.5 GB
- [Gaming ISO](link) - 3.5 GB
- [Developer ISO](link) - 4.0 GB

## Upgrade

```bash
orionos-cli update --apply
```

## Full Changelog

[CHANGELOG.md](link)

Thank you to all contributors!
```

## Post-Release Monitoring

### Metrics

- Download counts
- Update adoption rate
- Bug reports
- User feedback

### Response

- Critical bugs: Hotfix within 48 hours
- Major bugs: Fix in next patch release
- Minor bugs: Fix in next minor release

## Hotfix Process

For critical issues in stable releases:

```bash
# Create hotfix branch
git checkout main
git checkout -b hotfix/0.2.1

# Fix issue
# ... edit files ...

# Update version
sed -i 's/VERSION=.*/VERSION=0.2.1/' VERSION

# Commit and tag
git add .
git commit -m "fix: resolve critical issue

Fixes #789"
git tag -a v0.2.1 -m "OrionOS 0.2.1"
git push origin hotfix/0.2.1 --follow-tags

# CI/CD will build and release automatically

# Merge to main and develop
git checkout main
git merge hotfix/0.2.1
git checkout develop
git merge hotfix/0.2.1
```

## LTS Releases

### Support Timeline

| Version | Release Date | End of Life |
|---------|-------------|-------------|
| 1.0 LTS | 2024-06-01 | 2026-06-01 |
| 2.0 LTS | 2025-06-01 | 2027-06-01 |

### LTS Policy

- Security updates: Backported immediately
- Bug fixes: Backported monthly
- Features: Not backported (use current release)

## Rollback Procedure

If a release has critical issues:

1. **Immediate**: Notify users on all channels
2. **Short-term**: Provide workaround instructions
3. **Medium-term**: Prepare hotfix release
4. **If needed**: Roll back repository to previous version

```bash
# Roll back repository
cp /var/cache/orionos/repo-backup/pre-0.2.0/* /var/lib/pacman/sync/orionos/
repo-add orionos.db.tar.gz *.pkg.tar.zst
```

## Contact

- **Release Manager**: release@orionos.org
- **Security Issues**: security@orionos.org
- **General Questions**: dev@orionos.org
