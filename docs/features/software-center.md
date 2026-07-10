# OrionOS Software Center

## Overview
The OrionOS Software Center provides a graphical interface for discovering, installing, and managing software on OrionOS. It supports multiple package formats including Pacman, Flatpak, and AppImage.

## Features
- **Unified Interface**: Single application for all package formats
- **Pacman Integration**: Full Arch Linux repository support
- **Flatpak Support**: Access to Flatpak Flathub repository
- **AppImage Support**: Run AppImages without installation
- **Automatic Updates**: Keep all software up-to-date
- **Search & Browse**: Find software by category or search
- **Reviews & Ratings**: Community feedback on applications

## Package Format Support

### Pacman (Native Packages)
- Official Arch Linux repositories
- AUR (Arch User Repository) support
- OrionOS custom packages

### Flatpak
- Flathub repository integration
- Sandboxed applications
- Runtime dependencies

### AppImage
- Portable applications
- No installation required
- Automatic integration

## Usage

### Installing Software
1. Open Software Center from applications menu
2. Browse categories or search for software
3. Click "Install" on desired application
4. Authenticate with administrator password
5. Wait for installation to complete

### Updating Software
1. Open Software Center
2. Check for updates in "Updates" tab
3. Select packages to update
4. Click "Update Selected"

### Managing Installed Software
1. Go to "Installed" tab
2. View installed applications
3. Uninstall or update as needed

## Configuration

### Repository Configuration
The Software Center uses the following repositories:

```ini
# /etc/pacman.conf
[orionos]
SigLevel = PackageRequired
Server = https://repo.orionos.org/$arch

[core]
Include = /etc/pacman.d/mirrorlist

[extra]
Include = /etc/pacman.d/mirrorlist

[multilib]
Include = /etc/pacman.d/mirrorlist
```

### Flatpak Configuration
```bash
# Add Flathub repository
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Install Flatpak applications
flatpak install flathub com.spotify.Client
```

### AppImage Integration
AppImages are automatically integrated into the system:
- Desktop entries created
- Icons integrated
- Menu entries added

## Development

### Building
The Software Center is built using the OrionOS build system:

```bash
make packages EXTRA=orionos-software-center
```

### Architecture
- **Frontend**: Qt/QML interface
- **Backend**: C++ with package manager integration
- **Database**: Local cache for package metadata
- **Network**: Async HTTP client for repository access

### Adding New Package Formats
To add support for new package formats:
1. Create a new backend module in `src/backends/`
2. Implement the required interface
3. Register the backend in the main application
4. Update configuration

## Troubleshooting

### Package Installation Fails
1. Check internet connection
2. Verify repository configuration
3. Check disk space
4. Review log files in `/var/log/orionos-software-center/`

### Flatpak Issues
1. Verify Flatpak installation:
   ```bash
   flatpak --version
   flatpak remotes
   ```
2. Update Flatpak runtime:
   ```bash
   flatpak update
   ```

### AppImage Won't Run
1. Check FUSE installation:
   ```bash
   sudo pacman -S fuse2
   ```
2. Make AppImage executable:
   ```bash
   chmod +x *.AppImage
   ```

## References
- [Pacman Documentation](https://wiki.archlinux.org/title/Pacman)
- [Flatpak Documentation](https://docs.flatpak.org/)
- [AppImage Documentation](https://appimage.org/)
