#!/bin/bash
# ==============================================================================
# OrionOS Build System - ISO Image Builder
# Builds a bootable OrionOS ISO image using archiso
# ==============================================================================

set -euo pipefail

# Parse arguments
ARCH="x86_64"
PROFILE="default"
VERSION="0.1.0-alpha"
OUTPUT=""
COMPRESSION="zstd"
WORK_DIR=""

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
        --arch)
            ARCH="$2"
            shift 2
            ;;
        --profile)
            PROFILE="$2"
            shift 2
            ;;
        --version)
            VERSION="$2"
            shift 2
            ;;
        --output)
            OUTPUT="$2"
            shift 2
            ;;
        --compression)
            COMPRESSION="$2"
            shift 2
            ;;
        --work-dir)
            WORK_DIR="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --arch ARCH        Target architecture (default: x86_64)"
            echo "  --profile PROFILE  Build profile (default/gaming/developer/minimal)"
            echo "  --version VERSION  Release version"
            echo "  --output PATH      Output ISO path"
            echo "  --compression ALG  Compression algorithm (default: zstd)"
            echo "  --work-dir PATH    Working directory"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source logging
source "${SCRIPT_DIR}/logging.sh"

# Set output path
if [[ -z "$OUTPUT" ]]; then
    OUTPUT="${PROJECT_ROOT}/build/iso/orionos-${VERSION}-${ARCH}.iso"
fi

# Set working directory
if [[ -z "$WORK_DIR" ]]; then
    WORK_DIR="${PROJECT_ROOT}/build/work"
fi

# Default output directory
ISO_DIR="$(dirname "$OUTPUT")"
mkdir -p "$ISO_DIR"
mkdir -p "$WORK_DIR"

log_section "OrionOS ISO Build"
log_info "Architecture: $ARCH"
log_info "Profile: $PROFILE"
log_info "Version: $VERSION"
log_info "Output: $OUTPUT"
log_info "Working directory: $WORK_DIR"

# ==============================================================================
# Validate environment
# ==============================================================================
log_step "Validating build environment"

# Check for required tools
for tool in mkarchiso mksquashfs grub-mkrescue xorriso; do
    if ! command -v "$tool" &>/dev/null; then
        log_error "Required tool not found: $tool"
        log_info "Install archiso: pacman -S archiso"
        exit 1
    fi
done

log_info "Build environment validated"

# ==============================================================================
# Prepare archiso profile
# ==============================================================================
log_step "Preparing archiso profile"

PROFILE_SRC="${PROJECT_ROOT}/build/profiles/orionos"
PROFILE_WORK="${WORK_DIR}/profile"

# Clean and recreate working profile
rm -rf "$PROFILE_WORK"
cp -r "$PROFILE_SRC" "$PROFILE_WORK"

# Update profiledef.sh with build info
cat > "$PROFILE_WORK/profiledef.sh" << EOF
#!/usr/bin/env bash
# OrionOS ISO profile - generated $(date)

iso_name="orionos"
iso_label="ORIONOS_\$(date +%Y%m)"
iso_publisher="OrionOS <https://orionos.org>"
iso_application="OrionOS ${VERSION} (${PROFILE})"
iso_version="${VERSION}"
install_dir="arch"
bootmodes=('bios.syslinux.mbr' 'bios.syslinux.eltorito' 'uefi-ia32.grub.eltorito' 'uefi-x64.grub.eltorito' 'uefi-ia32.systemd-boot.esp' 'uefi-x64.systemd-boot.esp')
arch="${ARCH}"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' '${COMPRESSION}' '-Xcompression-level' '15' '-b' '1M')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/gshadow"]="0:0:400"
  ["/usr/bin/orionos-cli"]="0:0:755"
  ["/usr/bin/orionos-perfd"]="0:0:755"
  ["/usr/bin/orionos-updated"]="0:0:755"
  ["/usr/bin/orionos-powerd"]="0:0:755"
  ["/usr/bin/orionos-status"]="0:0:755"
  ["/usr/bin/orionos-installer"]="0:0:755"
)
EOF
chmod +x "$PROFILE_WORK/profiledef.sh"

# ==============================================================================
# Configure pacman for the build
# ==============================================================================
log_step "Configuring pacman for ISO build"

cat > "$PROFILE_WORK/pacman.conf" << 'EOF'
# OrionOS ISO pacman configuration
[options]
HoldPkg     = pacman glibc
Architecture = auto
CheckSpace
SigLevel    = Required DatabaseOptional
LocalFileSigLevel = Optional
ParallelDownloads = 8

[core]
Include = /etc/pacman.d/mirrorlist

[extra]
Include = /etc/pacman.d/mirrorlist

[multilib]
Include = /etc/pacman.d/mirrorlist

[orionos]
SigLevel = Optional TrustAll
Server = file:///repo/$repo/os/$arch
EOF

# ==============================================================================
# Copy packages to profile
# ==============================================================================
log_step "Adding OrionOS packages to profile"

mkdir -p "$PROFILE_WORK/airootfs/repo/orionos/os/x86_64"

# Copy built packages
if [[ -d "${PROJECT_ROOT}/build/repo/orionos/os/x86_64" ]]; then
    cp "${PROJECT_ROOT}/build/repo/orionos/os/x86_64/"*.pkg.tar.* \
        "$PROFILE_WORK/airootfs/repo/orionos/os/x86_64/" 2>/dev/null || true
    # Copy database
    cp "${PROJECT_ROOT}/build/repo/orionos/os/x86_64/"*.db* \
        "$PROFILE_WORK/airootfs/repo/orionos/os/x86_64/" 2>/dev/null || true
    cp "${PROJECT_ROOT}/build/repo/orionos/os/x86_64/"*.files* \
        "$PROFILE_WORK/airootfs/repo/orionos/os/x86_64/" 2>/dev/null || true
fi

# Create repo database in profile if packages exist
if ls "$PROFILE_WORK/airootfs/repo/orionos/os/x86_64/"*.pkg.tar.* &>/dev/null; then
    cd "$PROFILE_WORK/airootfs/repo/orionos/os/x86_64"
    repo-add orionos.db.tar.gz *.pkg.tar.* 2>/dev/null || true
    cd "$PROJECT_ROOT"
fi

# ==============================================================================
# Profile-specific package lists
# ==============================================================================
log_step "Setting up profile-specific packages"

# Base packages (always included)
cat > "$PROFILE_WORK/packages.x86_64" << 'EOF'
# OrionOS base packages
base
base-devel
linux
linux-headers
linux-firmware
mkinitcpio
mkinitcpio-archiso
btrfs-progs
grub-btrfs
snapper
snap-pac
grub
efibootmgr
os-prober
dosfstools
networkmanager
iwd
openssh
curl
wget
ntfs-3g
exfatprogs
udisks2
tar
gzip
bzip2
xz
zstd
zip
unzip
nano
vim
bash
bash-completion
zsh
zsh-completions
htop
btop
neofetch
inxi
pciutils
usbutils
lsof
strace
pacman-contrib
reflector
noto-fonts
noto-fonts-cjk
noto-fonts-emoji
terminus-font
mesa
mesa-utils
vulkan-intel
vulkan-radeon
pipewire
pipewire-pulse
pipewire-jack
pipewire-alsa
wireplumber
bluez
bluez-utils
EOF

# Add profile-specific packages
case "$PROFILE" in
    gaming)
        log_info "Adding gaming packages"
        cat >> "$PROFILE_WORK/packages.x86_64" << 'EOF'
# Gaming packages
steam
lutris
gamemode
lib32-gamemode
mangohud
lib32-mangohud
gamescope
vkd3d
lib32-vkd3d
dxvk
lib32-dxvk
wine-staging
winetricks
EOF
        ;;
    developer)
        log_info "Adding developer packages"
        cat >> "$PROFILE_WORK/packages.x86_64" << 'EOF'
# Developer packages
git
github-cli
nodejs
npm
python
python-pip
docker
docker-compose
podman
kubectl
helm
terraform
ansible
EOF
        ;;
    minimal)
        log_info "Minimal profile - no extra packages"
        ;;
esac

# Always add OrionOS packages
cat >> "$PROFILE_WORK/packages.x86_64" << 'EOF'
# OrionOS packages
orionos-config
orionos-desktop
orionos-security
orionos-services
orionos-themes
orionos-utils
EOF

# ==============================================================================
# Create airootfs overlays
# ==============================================================================
log_step "Setting up airootfs overlays"

AIROOTFS="$PROFILE_WORK/airootfs"

# System configuration
mkdir -p "$AIROOTFS/etc"

# Hostname
echo "orionos" > "$AIROOTFS/etc/hostname"

# Hosts
cat > "$AIROOTFS/etc/hosts" << 'EOF'
127.0.0.1   localhost
127.0.1.1   orionos
::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
EOF

# Locale
echo "en_US.UTF-8 UTF-8" > "$AIROOTFS/etc/locale.gen"
echo "LANG=en_US.UTF-8" > "$AIROOTFS/etc/locale.conf"

# Timezone
ln -sf /usr/share/zoneinfo/UTC "$AIROOTFS/etc/localtime"

# OrionOS-specific configuration
mkdir -p "$AIROOTFS/etc/orionos"
cat > "$AIROOTFS/etc/orionos/version" << EOF
NAME="OrionOS"
VERSION="${VERSION}"
ID=orionos
ID_LIKE=arch
PRETTY_NAME="OrionOS ${VERSION}"
ANSI_COLOR="38;2;180;190;254"
HOME_URL="https://orionos.org"
SUPPORT_URL="https://forum.orionos.org"
BUG_REPORT_URL="https://github.com/yousefelsharkawy26/OrionOS-Linux-Distro/issues"
EOF

# Create OrionOS release info
cp "$AIROOTFS/etc/orionos/version" "$AIROOTFS/etc/os-release"

# Live environment services
mkdir -p "$AIROOTFS/etc/systemd/system"
mkdir -p "$AIROOTFS/etc/systemd/system-preset"

cat > "$AIROOTFS/etc/systemd/system-preset/99-orionos-live.preset" << 'EOF'
enable NetworkManager.service
enable bluetooth.service
enable sshd.service
enable systemd-timesyncd.service
EOF

# Copy installer script
if [[ -f "${PROJECT_ROOT}/scripts/build/orionos-installer.sh" ]]; then
    cp "${PROJECT_ROOT}/scripts/build/orionos-installer.sh" \
        "$AIROOTFS/usr/bin/orionos-installer"
    chmod 755 "$AIROOTFS/usr/bin/orionos-installer"
fi

# ==============================================================================
# Build the ISO
# ==============================================================================
log_step "Building ISO image (this may take a while)"

# Remove old ISO if it exists
rm -f "$OUTPUT"

# Build with mkarchiso
if command -v mkarchiso &>/dev/null; then
    mkarchiso -v -w "$WORK_DIR" -o "$ISO_DIR" "$PROFILE_WORK" 2>&1 | while read -r line; do
        log_debug "$line"
    done
else
    log_error "mkarchiso not found. Install archiso package."
    exit 1
fi

# Find the generated ISO
GENERATED_ISO=$(find "$ISO_DIR" -maxdepth 1 -name "*.iso" -newer "$PROFILE_WORK/profiledef.sh" | head -1)

if [[ -n "$GENERATED_ISO" && -f "$GENERATED_ISO" ]]; then
    # Rename to our desired output name
    mv "$GENERATED_ISO" "$OUTPUT"
    log_info "ISO created: $OUTPUT"
else
    log_error "ISO creation failed - no output file found"
    exit 1
fi

# ==============================================================================
# Generate checksums
# ==============================================================================
log_step "Generating checksums"

cd "$ISO_DIR"
ISO_NAME=$(basename "$OUTPUT")

# SHA256
sha256sum "$ISO_NAME" > "${ISO_NAME}.sha256"
log_info "SHA256: $(cat "${ISO_NAME}.sha256" | awk '{print $1}')"

# SHA512
sha512sum "$ISO_NAME" > "${ISO_NAME}.sha512"
log_info "SHA512: $(cat "${ISO_NAME}.sha512" | awk '{print $1}')"

# MD5
md5sum "$ISO_NAME" > "${ISO_NAME}.md5"
log_info "MD5: $(cat "${ISO_NAME}.md5" | awk '{print $1}')"

log_info "Checksums written"

# ==============================================================================
# Summary
# ==============================================================================
log_section "ISO Build Complete"

ISO_SIZE=$(du -h "$OUTPUT" | cut -f1)
log_info "ISO: $OUTPUT"
log_info "Size: $ISO_SIZE"
log_info "Profile: $PROFILE"
log_info "Version: $VERSION"
log_info "Architecture: $ARCH"

echo ""
log_info "To test the ISO in QEMU:"
echo "  qemu-system-x86_64 -m 4G -cdrom $OUTPUT -boot d"
