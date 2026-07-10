# OrionOS System Architecture

## Overview

OrionOS is a modern Linux distribution built on Arch Linux, designed to deliver exceptional desktop performance, gaming capabilities, and integrated AI experiences. The architecture follows a modular, layered design that ensures maintainability, extensibility, and reliability.

## Design Philosophy

1. **Modularity**: Each subsystem is self-contained with well-defined interfaces
2. **Performance First**: Every component is optimized for desktop responsiveness
3. **User Experience**: macOS-inspired design with original identity
4. **Security**: Enterprise-grade security without compromising usability
5. **AI Integration**: Local-first AI with GPU acceleration
6. **Gaming Excellence**: First-class gaming support out of the box

## System Layers

```
┌─────────────────────────────────────────────────────────────┐
│                    User Applications                         │
│  (Firefox, VS Code, Steam, LibreOffice, etc.)               │
├─────────────────────────────────────────────────────────────┤
│                   Desktop Environment                        │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐   │
│  │ Hyprland │ │  Waybar  │ │  Rofi    │ │  Dunst       │   │
│  │ (WM)     │ │ (Bar)    │ │ (Launcher│ │ (Notifications│   │
│  └──────────┘ └──────────┘ └──────────┘ └──────────────┘   │
├─────────────────────────────────────────────────────────────┤
│                    AI Platform                               │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐   │
│  │  Model   │ │  Runtime │ │  Voice   │ │   OCR        │   │
│  │  Manager │ │  Manager │ │  Engine  │ │   Engine     │   │
│  └──────────┘ └──────────┘ └──────────┘ └──────────────┘   │
├─────────────────────────────────────────────────────────────┤
│                    Gaming Stack                              │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐   │
│  │  Steam   │ │  Proton  │ │ GameScope│ │  MangoHud    │   │
│  │  (Games) │ │(Compat.) │ │ (Display)│ │ (Overlay)    │   │
│  └──────────┘ └──────────┘ └──────────┘ └──────────────┘   │
├─────────────────────────────────────────────────────────────┤
│                   Ecosystem Services                         │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐   │
│  │  Device  │ │ Clipboard│ │  Nearby  │ │   Cloud      │   │
│  │  Manager │ │   Sync   │ │  Share   │ │   Sync       │   │
│  └──────────┘ └──────────┘ └──────────┘ └──────────────┘   │
├─────────────────────────────────────────────────────────────┤
│                   System Services                            │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐   │
│  │  Perf.   │ │  Update  │ │  Gaming  │ │  Battery     │   │
│  │  Service │ │  Service │ │  Service │ │  Service     │   │
│  └──────────┘ └──────────┘ └──────────┘ └──────────────┘   │
├─────────────────────────────────────────────────────────────┤
│                    Security Stack                            │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐   │
│  │ AppArmor │ │  TPM/    │ │  USB     │ │  Firewall    │   │
│  │  SELinux │ │  LUKS    │ │  Guard   │ │  (firewalld) │   │
│  └──────────┘ └──────────┘ └──────────┘ └──────────────┘   │
├─────────────────────────────────────────────────────────────┤
│                    Kernel Layer                              │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐   │
│  │  BORE    │ │  Btrfs   │ │  Vulkan  │ │  Network     │   │
│  │Scheduler │ │   FS     │ │  Drivers │ │  (BBR)       │   │
│  └──────────┘ └──────────┘ └──────────┘ └──────────────┘   │
├─────────────────────────────────────────────────────────────┤
│                    Hardware Layer                            │
│         (CPU, GPU, Storage, Network, Input)                  │
└─────────────────────────────────────────────────────────────┘
```

## Component Interactions

### Desktop Environment
- **Hyprland**: Core window manager handling tiling, floating, gestures, and animations
- **Waybar**: System panel showing workspaces, system status, and tray
- **Rofi**: Application launcher and window switcher
- **Dunst**: Notification daemon with custom styling
- **Swww**: Wallpaper daemon supporting dynamic wallpapers
- **Swaylock**: Lock screen with blur effects

### AI Platform
- **Model Manager**: Handles downloading, caching, and version management of AI models
- **Runtime Manager**: Abstracts multiple inference backends (llama.cpp, Ollama, vLLM, etc.)
- **API Server**: OpenAI-compatible REST API for uniform access
- **Voice Engine**: Speech-to-text and text-to-speech with GPU acceleration
- **OCR Engine**: Document and image text extraction
- **Plugin System**: Extensible automation framework

### Gaming Stack
- **Steam**: Primary game distribution platform
- **Proton**: Windows game compatibility layer
- **GameScope**: Micro-compositor for HDR and VRR support
- **MangoHud**: Performance overlay
- **GameMode**: Automatic performance optimization
- **DXVK/VKD3D**: DirectX-to-Vulkan translation

### Update System
The A/B update system works as follows:

1. **Pre-update**: Create Btrfs snapshot of current system
2. **Download**: Fetch updates to cache directory
3. **Verify**: Validate package signatures and integrity
4. **Apply**: Install updates atomically
5. **Recovery**: Bootloader stores recovery information for rollback
6. **Rollback**: Restore from snapshot if update fails

### Security Model

```
┌─────────────────────────────────────────┐
│         Application Layer                │
│  ┌─────────┐  ┌─────────┐  ┌────────┐ │
│  │ Firejail│  │AppArmor │  │ SELinux│ │
│  │Profiles │  │Profiles │  │Policies│ │
│  └─────────┘  └─────────┘  └────────┘ │
├─────────────────────────────────────────┤
│         System Call Layer                │
│         (seccomp-bpf filters)            │
├─────────────────────────────────────────┤
│         Kernel Security                  │
│  ┌─────────┐  ┌─────────┐  ┌────────┐ │
│  │  IMA    │  │  EVN    │  │ YAMA   │ │
│  │(Integrity│  │(Extended │  │(Ptrace │ │
│  │Measure) │  │Virt Attr)│  │Restrict│ │
│  └─────────┘  └─────────┘  └────────┘ │
├─────────────────────────────────────────┤
│         Hardware Security                │
│  ┌─────────┐  ┌─────────┐  ┌────────┐ │
│  │   TPM   │  │  LUKS   │  │ Secure │ │
│  │   2.0   │  │(FDE)   │  │  Boot  │ │
│  └─────────┘  └─────────┘  └────────┘ │
└─────────────────────────────────────────┘
```

## Filesystem Architecture

OrionOS uses Btrfs as the default filesystem with the following structure:

```
/                          [Btrfs root subvolume]
├── @                      [Root subvolume - current system]
├── @home                  [User data subvolume]
├── @snapshots             [System snapshots]
│   ├── pre-update-20240101-120000
│   └── pre-update-20240115-080000
├── @var                   [Variable data subvolume]
├── @tmp                  [Temporary data subvolume]
└── @swap                 [Swap file subvolume]
```

### Btrfs Features
- **Transparent Compression**: zstd compression for all files
- **Checksums**: CRC32C for data integrity
- **Snapshots**: Automatic snapshots before updates
- **Deduplication**: Background deduplication via bees
- **RAID**: Support for RAID0/1/10 configurations

## Boot Process

1. **UEFI Firmware**: Secure Boot verification
2. **Shim**: Chainloader for custom keys
3. **GRUB**: Bootloader with Btrfs and LUKS support
4. **Initramfs**: Unlock LUKS if encrypted, mount Btrfs subvolumes
5. **systemd**: Initialize system services
6. **Display Manager**: Ly or greetd for login
7. **Hyprland**: Start desktop session

## Network Architecture

- **TCP BBR**: Congestion control for better throughput
- **NetworkManager**: Connection management with iwd backend
- **firewalld**: Zone-based firewall
- **systemd-resolved**: DNS resolution with DNS-over-TLS support

## Memory Management

- **zRAM**: Compressed swap in RAM (50% of RAM size)
- **Zswap**: Compressed swap cache
- **Transparent Hugepages**: Automatic large page allocation
- **Auto NUMA**: Automatic NUMA balancing

## Performance Optimizations

### CPU
- BORE scheduler for better interactivity
- Schedutil governor with desktop tuning
- IRQ affinity for multi-core systems

### I/O
- mq-deadline/kyber I/O scheduler
- io_uring for asynchronous I/O
- Read-ahead tuning for desktop workloads

### GPU
- Early KMS for fast framebuffer initialization
- GPU memory tuning for gaming workloads
- Vulkan loader optimizations

## Extensibility Points

1. **Packages**: Add new packages to `packages/` directory
2. **Services**: Add systemd services to `services/`
3. **AI Plugins**: Add Python plugins to `ai/plugins/`
4. **Themes**: Add GTK/Qt themes to `themes/`
5. **Profiles**: Create custom installation profiles in `profiles/`

## Future Considerations

- **Containerization**: Podman/Docker integration for sandboxed apps
- **Wayland Compositors**: Support for alternative compositors
- **Mobile Integration**: Enhanced phone sync capabilities
- **Cloud Gaming**: Integration with cloud gaming services
- **AI Model Marketplace**: Curated model repository
