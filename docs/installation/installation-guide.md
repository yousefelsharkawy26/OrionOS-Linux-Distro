# OrionOS Installation Guide

## Overview
This guide walks you through installing OrionOS on your computer. OrionOS supports both UEFI and Legacy BIOS boot modes.

## System Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | x86_64, 2 cores | x86_64, 4+ cores |
| RAM | 4 GB | 16 GB |
| Storage | 40 GB | 100 GB SSD |
| GPU | Integrated | Dedicated (NVIDIA/AMD) |
| Network | Internet | Broadband |

## Pre-Installation

### 1. Download ISO
Download the latest OrionOS ISO from the [releases page](https://github.com/yousefelsharkawy26/OrionOS-Linux-Distro/releases).

### 2. Verify Checksum
```bash
sha256sum -c SHA256SUMS
```

### 3. Create Bootable USB

**Linux/macOS:**
```bash
sudo dd if=orionos-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

**Windows:**
Use [Rufus](https://rufus.ie/) with DD mode.

## Installation

### 1. Boot from USB
1. Insert USB drive
2. Restart computer
3. Enter BIOS/UEFI settings (usually F2, F12, or Del)
4. Boot from USB device

### 2. Start Installer
1. Select "Install OrionOS" from boot menu
2. Wait for live environment to load
3. Double-click "Install OrionOS" icon

### 3. Follow Installation Steps

#### Step 1: Welcome
- Select language
- Choose keyboard layout
- Set time zone

#### Step 2: Partitioning
**Automatic (Recommended):**
- Select "Erase disk and install OrionOS"
- Choose Btrfs filesystem
- Confirm partitioning

**Manual (Advanced):**
- Create custom partition layout
- Recommended layout:
  - `/boot/efi` - 512MB FAT32 (UEFI only)
  - `/` - 50GB Btrfs
  - `/home` - Remaining space Btrfs
  - `swap` - 2x RAM size (optional)

#### Step 3: User Setup
- Enter full name
- Choose username
- Set password
- Set hostname

#### Step 4: Review
- Review installation settings
- Click "Install" to begin

### 4. Complete Installation
1. Wait for installation to complete
2. Remove USB drive when prompted
3. Reboot into OrionOS

## Post-Installation

### 1. First Boot
1. Login with your credentials
2. Complete initial setup wizard
3. Connect to internet

### 2. Update System
```bash
orionos-cli update --apply
```

### 3. Enable Features
```bash
# Enable gaming optimizations
orionos-cli performance --profile gaming

# Enable AI platform
orionos-cli ai --enable

# Enable security features
orionos-cli security --setup
```

### 4. Install Additional Software
Open Software Center to install:
- Web browsers
- Office suites
- Media players
- Development tools

## Troubleshooting

### Boot Issues

**UEFI Boot Not Working:**
1. Disable Secure Boot in BIOS
2. Enable CSM support if needed
3. Try Legacy BIOS mode

**Black Screen After Boot:**
1. Add `nomodeset` to kernel parameters
2. Check GPU drivers
3. Try different display manager

### Installation Issues

**Insufficient Disk Space:**
- Minimum 40GB required
- Recommended 100GB for full installation

**Network Connection Issues:**
1. Check ethernet cable
2. Verify WiFi drivers
3. Try manual network configuration

### Post-Installation Issues

**No Sound:**
```bash
# Check audio devices
pactl list sinks

# Set default device
pactl set-default-source @DEFAULT_SOURCE@
pactl set-default-sink @DEFAULT_SINK@
```

**Display Issues:**
```bash
# Check display server
echo $XDG_SESSION_TYPE

# Restart display manager
sudo systemctl restart sddm
```

## Advanced Options

### Custom Kernel
Build custom kernel with OrionOS patches:
```bash
make kernel
sudo pacman -U build/linux-orionos-*.pkg.tar.zst
```

### Full Disk Encryption
Enable LUKS encryption during installation:
1. Select "Manual partitioning"
2. Create encrypted partition
3. Set encryption passphrase

### Dual Boot
Install alongside existing OS:
1. Shrink existing partition
2. Create new partition for OrionOS
3. Install GRUB to existing EFI partition

## Support

If you encounter issues:
1. Check [FAQ](../faq.md)
2. Search [GitHub Issues](https://github.com/yousefelsharkawy26/OrionOS-Linux-Distro/issues)
3. Join [Community Discord](https://discord.gg/orionos)
4. File a bug report

## Next Steps

After installation, explore:
- [Desktop Guide](../desktop/desktop-guide.md)
- [Gaming Setup](../features/game-optimization.md)
- [AI Platform](../features/ai-platform.md)
- [Security Configuration](../features/security.md)
