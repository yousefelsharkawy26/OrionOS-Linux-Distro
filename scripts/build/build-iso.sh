#!/bin/bash
# =============================================================================
# OrionOS ISO Generation Pipeline
# Builds a bootable ISO image with all OrionOS components
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Parse arguments
ARCH="x86_64"
PROFILE="default"
VERSION="0.1.0-alpha"
OUTPUT=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --arch) ARCH="$2"; shift 2 ;;
        --profile) PROFILE="$2"; shift 2 ;;
        --version) VERSION="$2"; shift 2 ;;
        --output) OUTPUT="$2"; shift 2 ;;
        *) log_error "Unknown option: $1"; exit 1 ;;
    esac
done

source "${PROJECT_ROOT}/scripts/build/logging.sh"

OUTPUT="${OUTPUT:-${PROJECT_ROOT}/build/iso/orionos-${VERSION}-${ARCH}.iso}"
WORK_DIR="${PROJECT_ROOT}/build/iso/work"
MOUNT_DIR="${PROJECT_ROOT}/build/iso/mount"

log_section "OrionOS ISO Generation"
log_info "Architecture: ${ARCH}"
log_info "Profile: ${PROFILE}"
log_info "Version: ${VERSION}"
log_info "Output: ${OUTPUT}"

# Clean work directory
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR" "$MOUNT_DIR" "$(dirname "$OUTPUT")"

# Copy archiso base
log_info "Setting up ISO workspace..."
cp -r /usr/share/archiso/configs/releng/* "$WORK_DIR/"

# Customize airootfs
log_info "Configuring airootfs..."
mkdir -p "${WORK_DIR}/airootfs/etc/orionos"

# Install OrionOS branding and configs
cp -r "${PROJECT_ROOT}/branding" "${WORK_DIR}/airootfs/etc/orionos/"
cp -r "${PROJECT_ROOT}/config" "${WORK_DIR}/airootfs/etc/orionos/"

# Copy custom packages to ISO
if [[ -d "${PROJECT_ROOT}/build/repo" ]]; then
    log_info "Adding custom packages to ISO..."
    mkdir -p "${WORK_DIR}/airootfs/opt/orionos/repo"
    cp -r "${PROJECT_ROOT}/build/repo"/* "${WORK_DIR}/airootfs/opt/orionos/repo/" || true
fi

# Configure pacman for OrionOS repos
log_info "Configuring package repositories..."
cat > "${WORK_DIR}/pacman.conf" << 'EOF'
[options]
HoldPkg = pacman glibc
Architecture = auto
CheckSpace
SigLevel = Required DatabaseOptional
LocalFileSigLevel = Optional

[core]
Include = /etc/pacman.d/mirrorlist

[extra]
Include = /etc/pacman.d/mirrorlist

[community]
Include = /etc/pacman.d/mirrorlist

[multilib]
Include = /etc/pacman.d/mirrorlist

[orionos]
Server = file:///opt/orionos/repo
SigLevel = Optional TrustAll
EOF

# Set up packages for ISO based on profile
log_info "Configuring package list for profile: ${PROFILE}..."
cat > "${WORK_DIR}/packages.x86_64" << EOF
# Base system
base
linux-firmware
intel-ucode
amd-ucode

# Boot
grub
efibootmgr
os-prober
shim
systemd-boot

# Filesystem
btrfs-progs
dosfstools
e2fsprogs
f2fs-tools
xfsprogs
ntfs-3g

# Networking
networkmanager
network-manager-applet
wireless_tools
wpa_supplicant
iwd
bluez
bluez-utils

# Audio
pipewire
pipewire-pulse
pipewire-jack
pipewire-alsa
wireplumber

# Graphics
mesa
mesa-utils
vulkan-intel
vulkan-radeon
nvidia-dkms
nvidia-utils
lib32-nvidia-utils
lib32-mesa

# Fonts
noto-fonts
noto-fonts-cjk
noto-fonts-emoji
noto-fonts-extra
ttf-dejavu
ttf-liberation

# Desktop (Hyprland)
hyprland
waybar
dunst
rofi-wayland
swaylock-effects
swww
wl-clipboard
grimblast
slurp
mako
libnotify
polkit-kde-agent
xdg-desktop-portal-hyprland
xdg-desktop-portal-gtk
qt5-wayland
qt6-wayland

# Terminal
alacritty
foot

# File manager
dolphin
nautilus
nemo

# Browser
firefox
chromium

# Utilities
unzip
zip
p7zip
zstd
lz4

# OrionOS custom packages
orionos-desktop
orionos-kernel
orionos-config
orionos-services
orionos-themes
orionos-utils
EOF

# Add profile-specific packages
case "$PROFILE" in
    gaming)
        cat >> "${WORK_DIR}/packages.x86_64" << 'EOF'
# Gaming
steam
gamemode
mangohud
lib32-vulkan-intel
lib32-vulkan-radeon
wine-staging
wine-gecko
wine-mono
lutris
heroic-games-launcher-bin
dxvk-bin
vkd3d-proton-bin
EOF
        ;;
    developer)
        cat >> "${WORK_DIR}/packages.x86_64" << 'EOF'
# Development
docker
podman
kubectl
helm
terraform
ansible
code
gcc
clang
rust
go
nodejs
npm
python
python-pip
git
cmake
ninja
meson
qemu-full
virt-manager
virt-viewer
dnsmasq
vde2
bridge-utils
openbsd-netcat
ebtables
iptables
libguestfs
EOF
        ;;
esac

# Create profile configuration
log_info "Creating profile configuration..."
cat > "${WORK_DIR}/airootfs/etc/orionos/profile.conf" << EOF
ORIONOS_PROFILE=${PROFILE}
ORIONOS_VERSION=${VERSION}
ORIONOS_ARCH=${ARCH}
EOF

# Configure bootloader for OrionOS branding
log_info "Configuring bootloader..."
mkdir -p "${WORK_DIR}/efiboot/loader/entries"
cat > "${WORK_DIR}/efiboot/loader/loader.conf" << 'EOF'
default orionos.conf
timeout 10
console-mode max
editor no
EOF

cat > "${WORK_DIR}/efiboot/loader/entries/orionos.conf" << EOF
title   OrionOS ${VERSION}
linux   /vmlinuz-linux-orionos
initrd  /intel-ucode.img
initrd  /amd-ucode.img
initrd  /initramfs-linux-orionos.img
options root=LABEL=ORIONOS_ROOT rw quiet splash
EOF

# Build ISO
log_info "Building ISO image..."
cd "$WORK_DIR"

# Use mkarchiso to build
if ! sudo mkarchiso -v -w "${WORK_DIR}/work" -o "$(dirname "$OUTPUT")" "$WORK_DIR" 2>&1 | tee "${PROJECT_ROOT}/build/logs/iso-build.log"; then
    log_error "ISO build failed. Check logs at ${PROJECT_ROOT}/build/logs/iso-build.log"
    exit 1
fi

# Rename output ISO
BUILT_ISO="$(find "$(dirname "$OUTPUT")" -name '*.iso' -mmin -5 | head -1)"
if [[ -n "$BUILT_ISO" && "$BUILT_ISO" != "$OUTPUT" ]]; then
    mv "$BUILT_ISO" "$OUTPUT"
fi

# Generate checksums
log_info "Generating checksums..."
cd "$(dirname "$OUTPUT")"
sha256sum "$(basename "$OUTPUT")" > "${OUTPUT}.sha256"
md5sum "$(basename "$OUTPUT")" > "${OUTPUT}.md5"

# Create torrent info
log_info "Creating torrent info..."
cat > "${OUTPUT}.torrent-info" << EOF
OrionOS ${VERSION} ${ARCH}
Architecture: ${ARCH}
Profile: ${PROFILE}
Version: ${VERSION}
Release Date: $(date -u +%Y-%m-%d)
SHA256: $(sha256sum "$OUTPUT" | cut -d' ' -f1)
EOF

log_success "ISO build complete!"
log_info "Output: ${OUTPUT}"
log_info "Size: $(du -h "$OUTPUT" | cut -f1)"
log_info "SHA256: $(sha256sum "$OUTPUT" | cut -d' ' -f1)"
