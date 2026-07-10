# OrionOS

[![Version](https://img.shields.io/badge/version-0.1.0--alpha-blue.svg)](https://orionos.org)
[![License](https://img.shields.io/badge/license-GPL--3.0-green.svg)](LICENSE)
[![Build](https://img.shields.io/github/actions/workflow/status/orionos/orionos/build.yml)](https://github.com/orionos/orionos/actions)

> A modern, performance-focused Linux distribution that combines the best of CachyOS, macOS, Hyprland, Arch Linux, SteamOS, and ChromeOS.

## Features

### Performance
- **Custom Kernel**: Based on Linux 6.11 with CachyOS optimizations
- **BORE Scheduler**: Better interactivity and lower latency
- **Gaming Optimizations**: Automatic game mode, CPU governor switching
- **Memory Management**: zRAM, transparent hugepages, auto NUMA
- **I/O Optimizations**: io_uring, optimized I/O schedulers
- **Network**: TCP BBR congestion control

### Desktop Experience
- **Hyprland Window Manager**: Smooth tiling with 120 FPS animations
- **macOS-Inspired Design**: Global top bar, animated dock, launchpad
- **Dynamic Wallpapers**: Time-based wallpaper switching
- **Blur Effects**: Rounded corners, backdrop blur, shadows
- **Adaptive Theme**: Automatic dark/light mode
- **Modern Notifications**: Styled notification daemon

### Gaming
- **Steam + Proton**: First-class Windows game compatibility
- **HDR & VRR**: High dynamic range and variable refresh rate
- **Auto-Optimization**: Per-game performance profiles
- **Performance Overlay**: MangoHud integration
- **GameScope**: Micro-compositor for gaming
- **Upscaling**: FSR and DLSS support

### AI Integration
- **Multi-Backend Support**: llama.cpp, Ollama, vLLM, ONNX, TensorRT-LLM
- **Model Management**: Download, switch, and manage AI models
- **Supported Models**: Qwen, Llama, Mistral, DeepSeek, Gemma, Phi, and more
- **Voice Assistant**: Speech-to-text and text-to-speech
- **OCR**: Document and image text extraction
- **Plugin System**: Extensible automation framework

### Security
- **Secure Boot**: Custom key enrollment
- **TPM + LUKS**: Hardware-backed full disk encryption
- **MAC**: AppArmor and SELinux policies
- **Sandboxed Apps**: Per-application permission system
- **Firewall**: Zone-based firewalld configuration
- **USBGuard**: USB device access control

### Ecosystem
- **Phone Sync**: Cross-device notifications and clipboard
- **Nearby Share**: AirDrop-like file sharing
- **Cloud Sync**: Support for Nextcloud, WebDAV, SFTP
- **Universal Control**: Share mouse/keyboard across devices

## Screenshots

*Coming soon - OrionOS is currently in alpha development*

## Installation

### System Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | x86_64, 2 cores | x86_64, 4+ cores |
| RAM | 4 GB | 16 GB |
| Storage | 40 GB | 100 GB SSD |
| GPU | Integrated | Dedicated (NVIDIA/AMD) |
| Network | Internet | Broadband |

### Download

Download the latest ISO from the [releases page](https://github.com/orionos/orionos/releases).

```bash
# Verify checksum
sha256sum -c SHA256SUMS
```

### Create Bootable USB

```bash
# Using dd (Linux/macOS)
sudo dd if=orionos-*.iso of=/dev/sdX bs=4M status=progress oflag=sync

# Using Rufus (Windows) - Select DD mode
```

### Install

1. Boot from USB drive
2. Select "Install OrionOS" from the boot menu
3. Follow the graphical installer
4. Reboot and enjoy!

### Post-Installation

```bash
# Update system
orionos-cli update --apply

# Check system health
orionos-cli doctor

# Enable gaming optimizations
orionos-cli performance --profile gaming
```

## Building from Source

### Prerequisites

- Arch Linux or Arch-based distribution
- 50 GB free disk space
- Internet connection
- `base-devel` package group

### Build

```bash
# Clone repository
git clone https://github.com/orionos/orionos.git
cd orionos

# Initialize build environment
make init

# Build everything
make all

# Or build specific components
make kernel          # Build custom kernel
make packages        # Build packages
make iso            # Generate ISO
```

### Build Profiles

| Profile | Description |
|---------|-------------|
| `default` | Balanced desktop experience |
| `gaming` | Optimized for gaming |
| `developer` | Includes dev tools and IDEs |
| `minimal` | Minimal installation |

```bash
# Build gaming ISO
make PROFILE=gaming all
```

## Documentation

- [System Architecture](docs/architecture/system-architecture.md)
- [Kernel Modifications](docs/kernel-modifications.md)
- [Desktop Architecture](docs/desktop-architecture.md)
- [Update System](docs/update-system.md)
- [Security Model](docs/security-model.md)
- [AI Platform](docs/ai-platform.md)
- [Developer Guide](docs/developer-guide.md)
- [Contribution Guide](docs/contribution-guide.md)
- [Release Process](docs/release-process.md)

## Project Structure

```
orionos/
├── packages/          # Package definitions (PKGBUILDs)
│   ├── core/         # Core system packages
│   ├── extra/        # Additional packages
│   └── community/    # Community packages
├── kernel/           # Custom kernel build
│   ├── patches/      # Kernel patches
│   ├── config/       # Kernel configurations
│   └── scripts/      # Build scripts
├── desktop/          # Desktop environment configs
│   ├── hyprland/     # Window manager config
│   ├── waybar/       # Status bar config
│   ├── rofi/         # Launcher config
│   └── wallpapers/   # Wallpaper collection
├── services/         # System services
│   ├── systemd/      # Service definitions
│   └── scripts/      # Service implementations
├── ai/               # AI platform
│   ├── runtime/      # Runtime backends
│   ├── models/       # Model configurations
│   └── plugins/      # Plugin system
├── gaming/           # Gaming stack
│   ├── steam/        # Steam configuration
│   ├── proton/       # Proton settings
│   └── optimizations/# Performance profiles
├── security/         # Security configuration
│   ├── selinux/      # SELinux policies
│   ├── apparmor/     # AppArmor profiles
│   └── firewall/     # Firewall rules
├── ecosystem/        # Cross-device services
│   ├── sync/         # Synchronization
│   ├── sharing/      # File sharing
│   └── cloud/        # Cloud integration
├── branding/         # Visual identity
│   ├── logo/         # Logo assets
│   ├── colors/       # Color palette
│   └── fonts/        # Typography
├── themes/           # UI themes
│   ├── gtk/          # GTK themes
│   ├── icon/         # Icon themes
│   ├── cursor/       # Cursor themes
│   └── sound/        # Sound themes
├── scripts/          # Build and utility scripts
│   ├── build/        # Build system
│   ├── install/      # Installation scripts
│   └── maintain/     # Maintenance scripts
├── build/            # Build output
│   ├── iso/          # Generated ISOs
│   ├── packages/     # Built packages
│   └── repo/         # Package repository
├── ci/               # CI/CD configuration
│   └── github-actions/ # GitHub Actions workflows
├── testing/          # Test suite
│   ├── unit/         # Unit tests
│   ├── integration/  # Integration tests
│   └── performance/  # Performance tests
└── docs/             # Documentation
    ├── architecture/ # System architecture
    ├── installation/ # Installation guide
    ├── development/  # Developer guide
    └── security/     # Security documentation
```

## Technology Stack

| Layer | Technology |
|-------|-----------|
| Base | Arch Linux |
| Kernel | Linux 6.11 + CachyOS patches |
| Filesystem | Btrfs |
| Init | systemd |
| Display | Wayland (Hyprland) |
| Audio | PipeWire |
| Networking | NetworkManager + iwd |
| Security | AppArmor + SELinux + firewalld |
| Package Manager | pacman + AUR + Flatpak |
| AI Runtime | llama.cpp, Ollama, vLLM |

## Contributing

We welcome contributions! Please see our [Contribution Guide](docs/contribution-guide.md) for details.

### Quick Start

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `./testing/run-tests.sh`
5. Submit a pull request

### Code of Conduct

This project adheres to a code of conduct. By participating, you are expected to uphold this code.

## License

OrionOS is licensed under the GNU General Public License v3.0. See [LICENSE](LICENSE) for details.

## Acknowledgments

- **Arch Linux** - Base distribution
- **CachyOS** - Kernel patches and optimizations
- **Hyprland** - Window manager
- **Steam/Valve** - Proton and gaming technologies
- **Google** - ChromeOS update system inspiration
- **Apple** - Design philosophy inspiration

## Community

- **Website**: [orionos.org](https://orionos.org)
- **Forum**: [forum.orionos.org](https://forum.orionos.org)
- **Discord**: [discord.gg/orionos](https://discord.gg/orionos)
- **Matrix**: #orionos:matrix.org
- **Twitter**: [@OrionOS_Linux](https://twitter.com/OrionOS_Linux)

## Roadmap

### v0.1.0 Alpha (Current)
- [x] Base system and build pipeline
- [x] Custom kernel with CachyOS optimizations
- [x] Hyprland desktop environment
- [x] Security stack (AppArmor, firewalld, USBGuard)
- [x] Gaming stack (Steam, Proton, GameMode)
- [x] AI platform (multi-backend support)
- [x] Update system (A/B updates)
- [x] Btrfs filesystem with snapshots

### v0.2.0 Beta
- [ ] Graphical installer (Calamares)
- [ ] Software center (pacman + Flatpak + AppImage)
- [ ] Phone sync mobile app
- [ ] Improved game auto-optimization
- [ ] Voice assistant integration
- [ ] HDR/VRR improvements

### v1.0.0 Stable
- [ ] Full Secure Boot support
- [ ] TPM + LUKS auto-setup
- [ ] Cloud synchronization GUI
- [ ] Plugin marketplace
- [ ] Documentation completion
- [ ] Stability and polish

### Future
- [ ] ARM64 support
- [ ] Containerized applications
- [ ] AI model marketplace
- [ ] Cloud gaming integration
- [ ] Mobile companion app

---

<p align="center">
  <strong>OrionOS</strong> - The Future of Desktop Linux
  <br>
  Made with ♥ by the OrionOS Team
</p>
