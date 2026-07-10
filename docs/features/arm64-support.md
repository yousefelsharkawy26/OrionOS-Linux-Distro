# OrionOS ARM64 Support

## Overview
Full ARM64/aarch64 architecture support including cross-compilation, device flashing, and emulation via QEMU/binfmt_misc.

## Supported Devices
- Raspberry Pi 4/5
- ODROID-N2/N2+
- Pine64 Quartz64-A
- Orange Pi 5/5 Plus
- Generic ARM64 (UEFI)

## Usage

### Setup
```bash
sudo orionos-arm64-setup setup
```

### Cross-compile for ARM64
```bash
source /opt/orionos/arm64-cross/aarch64-env.sh
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-
```

### Flash to SD Card/eMMC
```bash
# List supported boards
sudo orionos-arm64-flash boards

# Flash Raspberry Pi
sudo orionos-arm64-flash rpi /dev/sdX

# Flash generic ARM64 image
sudo orionos-arm64-flash flash /dev/sdX generic ./orionos-arm64.img
```

### Check Status
```bash
sudo orionos-arm64-setup status
```
