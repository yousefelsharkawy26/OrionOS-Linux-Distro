#!/bin/bash
# ==============================================================================
# OrionOS Build System - Environment Initialization
# Sets up the build environment for ISO/package builds
# ==============================================================================

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source logging
source "${SCRIPT_DIR}/logging.sh"

# Target architecture
ARCH="${1:-x86_64}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_section "OrionOS Build Environment Initialization"

# ==============================================================================
# Check if running on Arch Linux
# ==============================================================================
log_step "Checking host system"
if [[ ! -f /etc/arch-release ]]; then
    log_warn "This is not Arch Linux. Some features may not work correctly."
    log_info "OrionOS is designed to be built on Arch Linux or an Arch-based distribution."
fi

# ==============================================================================
# Check architecture
# ==============================================================================
log_step "Checking architecture: $ARCH"
if [[ "$ARCH" != "x86_64" ]]; then
    log_fatal "Unsupported architecture: $ARCH"
    log_info "Currently only x86_64 is supported"
    exit 1
fi
log_info "Architecture: $ARCH"

# ==============================================================================
# Install required packages
# ==============================================================================
log_step "Installing build dependencies"

# Base development tools
BASE_DEPS=(
    base-devel
    arch-install-scripts
    btrfs-progs
    dosfstools
    e2fsprogs
    efibootmgr
    grub
    libisoburn
    mtools
    nasm
    openssl
    parted
    patch
    sed
    squashfs-tools
    syslinux
)

# Package building tools
PKG_DEPS=(
    devtools
    archiso
    pacman-contrib
    namcap
)

# Signing tools
SIGN_DEPS=(
    gnupg
    openssl
)

# Optional tools
OPT_DEPS=(
    qemu-desktop
    qemu-emulators-full
    ovmf
)

# Combine all deps
ALL_DEPS=("${BASE_DEPS[@]}" "${PKG_DEPS[@]}" "${SIGN_DEPS[@]}")

# Check which packages are already installed
MISSING_DEPS=()
for dep in "${ALL_DEPS[@]}"; do
    if ! pacman -Qi "$dep" &>/dev/null; then
        MISSING_DEPS+=("$dep")
    fi
done

if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
    log_info "Missing packages: ${MISSING_DEPS[*]}"
    log_info "Installing dependencies..."
    
    # Update package database
    pacman -Sy --noconfirm
    
    # Install missing packages
    if ! pacman -S --noconfirm --needed "${MISSING_DEPS[@]}"; then
        log_error "Failed to install some packages"
        log_info "You may need to install them manually:"
        for dep in "${MISSING_DEPS[@]}"; do
            echo "  - $dep"
        done
        exit 1
    fi
else
    log_info "All dependencies are already installed"
fi

# ==============================================================================
# Create build directories
# ==============================================================================
log_step "Creating build directories"

BUILD_DIRS=(
    "${PROJECT_ROOT}/build/iso"
    "${PROJECT_ROOT}/build/packages"
    "${PROJECT_ROOT}/build/kernel"
    "${PROJECT_ROOT}/build/repo"
    "${PROJECT_ROOT}/build/logs"
    "${PROJECT_ROOT}/build/cache"
    "${PROJECT_ROOT}/build/work"
    "${PROJECT_ROOT}/build/profiles"
    "${PROJECT_ROOT}/build/airootfs"
)

for dir in "${BUILD_DIRS[@]}"; do
    mkdir -p "$dir"
    log_debug "Created: $dir"
done

log_info "Build directories created"

# ==============================================================================
# Configure pacman for build
# ==============================================================================
log_step "Configuring pacman"

# Enable multilib repository if not already enabled
if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
    log_info "Enabling multilib repository..."
    cat >> /etc/pacman.conf << 'EOF'

[multilib]
Include = /etc/pacman.d/mirrorlist
EOF
    pacman -Sy
else
    log_info "Multilib repository already enabled"
fi

# ==============================================================================
# Setup GPG for package signing (if not already configured)
# ==============================================================================
log_step "Checking GPG configuration"

if [[ -z "${GPG_KEY:-}" ]]; then
    # Check for existing OrionOS key
    ORIONOS_KEY=$(gpg --list-secret-keys --with-colons 2>/dev/null | \
        grep -i "orionos" | head -1 | cut -d: -f5 || true)
    
    if [[ -n "$ORIONOS_KEY" ]]; then
        export GPG_KEY="$ORIONOS_KEY"
        log_info "Found existing OrionOS GPG key: $GPG_KEY"
    else
        log_warn "No GPG key configured for package signing"
        log_info "Generate one with: gpg --full-generate-key"
        log_info "Then set GPG_KEY environment variable"
    fi
else
    log_info "GPG key configured: $GPG_KEY"
fi

# ==============================================================================
# Create archiso profile if it doesn't exist
# ==============================================================================
log_step "Setting up archiso profile"

PROFILE_DIR="${PROJECT_ROOT}/build/profiles/orionos"
mkdir -p "$PROFILE_DIR"

# Create profiledef.sh
if [[ ! -f "$PROFILE_DIR/profiledef.sh" ]]; then
    cat > "$PROFILE_DIR/profiledef.sh" << 'EOF'
#!/usr/bin/env bash
# OrionOS ISO profile

build_date="$(date +%Y.%m.%d)"
iso_name="orionos"
iso_label="ORIONOS_$(date +%Y%m)"
iso_publisher="OrionOS <https://orionos.org>"
iso_application="OrionOS Live/Rescue CD"
iso_version="0.1.0-alpha"
install_dir="arch"
bootmodes=('bios.syslinux.mbr' 'bios.syslinux.eltorito' 'uefi-ia32.grub.eltorito' 'uefi-x64.grub.eltorito' 'uefi-ia32.systemd-boot.esp' 'uefi-x64.systemd-boot.esp')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15' '-b' '1M')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/gshadow"]="0:0:400"
  ["/usr/bin/orionos-cli"]="0:0:755"
  ["/usr/bin/orionos-perfd"]="0:0:755"
  ["/usr/bin/orionos-updated"]="0:0:755"
  ["/usr/bin/orionos-powerd"]="0:0:755"
  ["/usr/bin/orionos-status"]="0:0:755"
)
EOF
    chmod +x "$PROFILE_DIR/profiledef.sh"
    log_info "Created archiso profile"
else
    log_info "Archiso profile already exists"
fi

# Create pacman.conf for ISO
if [[ ! -f "$PROFILE_DIR/pacman.conf" ]]; then
    cat > "$PROFILE_DIR/pacman.conf" << 'EOF'
# OrionOS ISO pacman configuration
[options]
HoldPkg     = pacman glibc
Architecture = auto
CheckSpace
SigLevel    = Required DatabaseOptional
LocalFileSigLevel = Optional

[core]
Include = /etc/pacman.d/mirrorlist

[extra]
Include = /etc/pacman.d/mirrorlist

[multilib]
Include = /etc/pacman.d/mirrorlist

[orionos]
SigLevel = Required DatabaseOptional
Server = file:///repo/$repo/os/$arch
EOF
    log_info "Created ISO pacman configuration"
fi

# ==============================================================================
# Create airootfs overlay
# ==============================================================================
log_step "Setting up airootfs overlay"

AIROOTFS_DIR="${PROFILE_DIR}/airootfs"
mkdir -p "$AIROOTFS_DIR/etc"

# Set hostname
echo "orionos" > "$AIROOTFS_DIR/etc/hostname"

# Create hosts file
cat > "$AIROOTFS_DIR/etc/hosts" << 'EOF'
# OrionOS hosts file
127.0.0.1   localhost
127.0.1.1   orionos
::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
EOF

# Set timezone link
mkdir -p "$AIROOTFS_DIR/etc"
ln -sf /usr/share/zoneinfo/UTC "$AIROOTFS_DIR/etc/localtime"

# Locale
mkdir -p "$AIROOTFS_DIR/etc"
echo "en_US.UTF-8 UTF-8" > "$AIROOTFS_DIR/etc/locale.gen"
echo "LANG=en_US.UTF-8" > "$AIROOTFS_DIR/etc/locale.conf"

log_info "Airootfs overlay created"

# ==============================================================================
# Create package lists for ISO
# ==============================================================================
log_step "Creating package lists"

mkdir -p "$PROFILE_DIR/packages"

# Base packages
cat > "$PROFILE_DIR/packages.x86_64" << 'EOF'
# OrionOS base packages

# Base system
base
base-devel
linux
linux-headers
linux-firmware
mkinitcpio
mkinitcpio-archiso

# Btrfs
btrfs-progs
grub-btrfs
snapper
snap-pac

# Boot
grub
efibootmgr
os-prober
dosfstools

# Network
networkmanager
iwd
openssh
curl
wget

# Filesystem tools
ntfs-3g
exfatprogs
udisks2

# Compression
tar
gzip
bzip2
xz
zstd
zip
unzip

# Text editors
nano
vim

# Shell
bash
bash-completion
zsh
zsh-completions

# System utilities
htop
btop
neofetch
inxi
pciutils
usbutils
lsof
strace

# Pacman tools
pacman-contrib
reflector
paru

# Fonts
noto-fonts
noto-fonts-cjk
noto-fonts-emoji
terminus-font

# Display
mesa
mesa-utils
vulkan-intel
vulkan-radeon

# Audio
pipewire
pipewire-pulse
pipewire-jack
pipewire-alsa
wireplumber

# Bluetooth
bluez
bluez-utils

# OrionOS packages
orionos-config
orionos-desktop
orionos-security
orionos-services
orionos-themes
orionos-utils
EOF

log_info "Package list created"

# ==============================================================================
# Create systemd units for live environment
# ==============================================================================
log_step "Configuring live environment services"

mkdir -p "$AIROOTFS_DIR/etc/systemd/system"

# Enable services in the live environment
mkdir -p "$AIROOTFS_DIR/etc/systemd/system"
mkdir -p "$AIROOTFS_DIR/etc/systemd/system/multi-user.target.wants"
mkdir -p "$AIROOTFS_DIR/etc/systemd/system/network-online.target.wants"

# Create a preset file for the live environment
mkdir -p "$AIROOTFS_DIR/etc/systemd/system-preset"
cat > "$AIROOTFS_DIR/etc/systemd/system-preset/99-orionos-live.preset" << 'EOF'
enable NetworkManager.service
enable bluetooth.service
enable sshd.service
enable sddm.service
enable gdm.service
EOF

# ==============================================================================
# Create boot entries
# ==============================================================================
log_step "Creating boot entries"

# syslinux BIOS boot
mkdir -p "$PROFILE_DIR/syslinux"
cat > "$PROFILE_DIR/syslinux/syslinux-linux.cfg" << 'EOF'
LABEL orionos
MENU LABEL OrionOS
LINUX boot/x86_64/vmlinuz-linux
INITRD boot/intel-ucode.img,boot/amd-ucode.img,boot/x86_64/initramfs-linux.img
APPEND archisobasedir=%ARCHISO_DIR% archisolabel=%ARCHISO_LABEL% cow_spacesize=10G

LABEL orionos-nvidia
MENU LABEL OrionOS (NVIDIA)
LINUX boot/x86_64/vmlinuz-linux
INITRD boot/intel-ucode.img,boot/amd-ucode.img,boot/x86_64/initramfs-linux.img
APPEND archisobasedir=%ARCHISO_DIR% archisolabel=%ARCHISO_LABEL% cow_spacesize=10G nvidia-drm.modeset=1 modprobe.blacklist=nouveau
EOF

log_info "Boot entries created"

# ==============================================================================
# Summary
# ==============================================================================
log_section "Environment Initialization Complete"

log_info "Architecture: $ARCH"
log_info "Build directory: ${PROJECT_ROOT}/build"
log_info "Profile directory: $PROFILE_DIR"
log_info "Log file: ${LOG_FILE:-none}"

echo ""
log_info "You can now build OrionOS:"
echo "  make kernel     - Build custom kernel"
echo "  make packages   - Build packages"
echo "  make iso        - Generate ISO image"
echo "  make all        - Build everything"
