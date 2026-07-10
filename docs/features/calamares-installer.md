# OrionOS Calamares Installer

## Overview
The OrionOS Calamares Installer provides a graphical installation experience for OrionOS, similar to popular distributions like Ubuntu, Fedora, and Manjaro.

## Features
- **User-friendly GUI**: Intuitive step-by-step installation process
- **Automatic partitioning**: Btrfs filesystem with automatic partition layout
- **Manual partitioning**: Advanced users can customize partition layout
- **User configuration**: Username, password, hostname setup
- **Bootloader installation**: GRUB bootloader configuration
- **Post-installation setup**: Automatic package installation and configuration

## Installation Process

### 1. Welcome Screen
- Language selection
- Keyboard layout configuration
- Time zone selection

### 2. Partitioning
- **Automatic**: Guided partitioning with Btrfs
- **Manual**: Advanced partitioning for custom layouts

### 3. User Setup
- Username and password configuration
- Hostname setting
- Optional: Import existing user data

### 4. Installation
- Package installation progress
- System configuration
- Bootloader setup

### 5. Completion
- Installation summary
- Reboot prompt

## Configuration

### Installer Configuration
The installer uses Calamares with the following configuration:

```yaml
# /etc/calamares/settings.conf
modules:
  - welcome
  - keyboard
  - locale
  - partition
  - users
  - package
  - bootloader
  - finish

partition:
  defaultFilesystem: btrfs
  defaultMountPoint: /
  
users:
  defaultGroups:
    - wheel
    - audio
    - video
    - optical
    - storage
    - network
    - power
```

### Branding
Custom OrionOS branding:
- Logo: `branding/orionos/logo.png`
- Welcome image: `branding/orionos/welcome.png`
- Color scheme: OrionOS brand colors

## Post-Installation

After installation, the following is automatically configured:
- System packages from `packages/core/`
- Desktop environment (Hyprland)
- Gaming stack (Steam, Proton, GameMode)
- AI platform
- Security configurations
- System services

## Troubleshooting

### Installation Fails
1. Check disk space (minimum 40GB)
2. Verify internet connection
3. Check log files in `/var/log/calamares/`

### Bootloader Issues
1. Verify UEFI/Legacy boot mode matches installation
2. Check GRUB configuration in `/boot/grub/grub.cfg`
3. Reinstall GRUB if needed:
   ```bash
   sudo grub-install --target=x86_64-efi --efi-directory=/boot
   sudo grub-mkconfig -o /boot/grub/grub.cfg
   ```

## Development

### Building
The installer package is built using the OrionOS build system:

```bash
make packages EXTRA=calamares
```

### Customization
To customize the installer:
1. Modify `packages/extra/calamares/calamares.conf`
2. Update branding assets in `branding/orionos/`
3. Rebuild packages

## References
- [Calamares Documentation](https://calamares.io/)
- [OrionOS Installation Guide](docs/installation/installation-guide.md)
