# OrionOS

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://orionos.org)
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

# Option 1: Native build (requires Arch Linux)
make init
make all

# Option 2: Docker build (any Linux with Docker)
make docker-iso
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

# Build developer ISO
make PROFILE=developer docker-iso
```

### Building the ISO

The ISO can be built two ways:

**Method 1: Docker (Recommended)**
```bash
make docker-iso
# Output: build/iso/orionos-1.0.0-x86_64.iso
```

**Method 2: Native Arch Linux**
```bash
make init      # Install build dependencies
make iso       # Build ISO
```

**Testing the ISO**
```bash
# QEMU/KVM
qemu-system-x86_64 -m 4G -cdrom build/iso/orionos-*.iso -boot d

# Write to USB
sudo dd if=build/iso/orionos-*.iso of=/dev/sdX bs=4M status=progress && sync
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

### Core
- [System Architecture](docs/architecture/system-architecture.md)
- [Kernel Modifications](docs/kernel-modifications.md)
- [Desktop Architecture](docs/desktop-architecture.md)
- [Update System](docs/update-system.md)
- [Security Model](docs/security-model.md)
- [AI Platform](docs/ai-platform.md)

### Features (v0.2.0 Beta)
- [Calamares Installer](docs/features/calamares-installer.md)
- [Software Center](docs/features/software-center.md)
- [Game Optimization](docs/features/game-optimization.md)
- [Voice Assistant](docs/features/voice-assistant.md)
- [Phone Sync](docs/features/phone-sync.md)
- [Display Optimization](docs/features/display-optimization.md)

### Features (v1.0.0 Stable)
- [Secure Boot](docs/features/secureboot.md)
- [TPM + LUKS](docs/features/tpm-luks.md)
- [Cloud Sync GUI](docs/features/cloud-sync-gui.md)
- [Plugin Marketplace](docs/features/plugin-marketplace.md)

### Features (Future)
- [ARM64 Support](docs/features/arm64-support.md)
- [Containerized Apps](docs/features/containers.md)
- [AI Model Marketplace](docs/features/ai-marketplace.md)
- [Cloud Gaming](docs/features/cloud-gaming.md)
- [Mobile Companion](docs/features/mobile-companion.md)

### Guides
- [Installation Guide](docs/installation/installation-guide.md)
- [Desktop Guide](docs/desktop/desktop-guide.md)
- [Developer Guide](docs/developer-guide.md)
- [Contribution Guide](docs/contribution-guide.md)
- [Release Process](docs/release-process.md)

## Project Structure

```
orionos/
├── packages/          # Package definitions (PKGBUILDs)
│   ├── core/         # Core system packages
│   │   ├── orionos-config/
│   │   ├── orionos-desktop/
│   │   ├── orionos-security/
│   │   ├── orionos-services/
│   │   ├── orionos-themes/
│   │   ├── orionos-utils/
│   │   ├── orionos-voice-assistant/
│   │   ├── orionos-secureboot/
│   │   ├── orionos-tpm-luks/
│   │   └── orionos-arm64-support/
│   ├── extra/        # Additional packages
│   │   ├── calamares/
│   │   ├── orionos-software-center/
│   │   ├── orionos-game-optimize/
│   │   ├── orionos-display-optimization/
│   │   ├── orionos-cloud-sync/
│   │   ├── orionos-plugin-marketplace/
│   │   ├── orionos-containers/
│   │   ├── orionos-ai-marketplace/
│   │   └── orionos-cloud-gaming/
│   └── community/    # Community packages
├── kernel/           # Custom kernel build
├── desktop/          # Desktop environment configs
├── services/         # System services
├── ai/               # AI platform
├── gaming/           # Gaming stack
├── security/         # Security configuration
├── ecosystem/        # Cross-device services
│   ├── phone-sync/   # Phone sync
│   │   ├── desktop/  # Rust desktop service
│   │   ├── cloud/    # Go cloud service
│   │   └── proto/    # Protocol Buffers
│   └── mobile-companion/ # Full mobile companion
│       ├── desktop/  # Rust desktop client
│       ├── cloud/    # Go cloud relay
│       └── proto/    # Protocol Buffers
├── scripts/          # Build and utility scripts
├── testing/          # Test suite
│   └── run-tests.sh  # Test runner
├── docs/             # Documentation
│   ├── features/     # Feature documentation
│   └── installation/ # Installation guides
└── build/            # Build output
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

### v0.1.0 Alpha ✅ Complete
- [x] Base system and build pipeline
- [x] Custom kernel with CachyOS optimizations
- [x] Hyprland desktop environment
- [x] Security stack (AppArmor, firewalld, USBGuard)
- [x] Gaming stack (Steam, Proton, GameMode)
- [x] AI platform (multi-backend support)
- [x] Update system (A/B updates)
- [x] Btrfs filesystem with snapshots

### v0.2.0 Beta ✅ Complete
- [x] Graphical installer (Calamares)
- [x] Software center (pacman + Flatpak + AppImage)
- [x] Phone sync mobile app (Rust desktop + Go cloud)
- [x] Improved game auto-optimization
- [x] Voice assistant integration
- [x] HDR/VRR improvements

### v1.0.0 Stable ✅ Complete
- [x] Full Secure Boot support
- [x] TPM + LUKS auto-setup
- [x] Cloud synchronization GUI
- [x] Plugin marketplace
- [x] Documentation completion
- [x] Stability and polish

### Future ✅ Complete
- [x] ARM64 support
- [x] Containerized applications
- [x] AI model marketplace
- [x] Cloud gaming integration
- [x] Mobile companion app
- [x] Bootable ISO build system

---

<p align="center">
  <strong>OrionOS</strong> - The Future of Desktop Linux
  <br>
  Made with ♥ by the OrionOS Team
</p>
