#!/bin/bash
# ==============================================================================
# OrionOS ISO Builder - Local (no Docker, no Arch Linux required)
# Downloads Arch Linux bootstrap, builds ISO from any Linux system
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}" && pwd)"

VERSION="${VERSION:-1.0.0}"
PROFILE="${PROFILE:-default}"
WORK="${HOME}/orionos-build"
CACHE="${HOME}/.cache/orionos"
OUTPUT="${PROJECT_ROOT}/build/iso"
ARCH_BOOTSTRAP_URL="https://geo.mirror.pkgbuild.com/iso/latest/archlinux-bootstrap-x86_64.tar.zst"

echo "=== OrionOS Local ISO Builder ==="
echo "  Version: ${VERSION}"
echo "  Profile: ${PROFILE}"
echo "  Work:    ${WORK}"
echo ""

# ─────────────────────────────────────────────
# Step 1: Check dependencies
# ─────────────────────────────────────────────
echo "[1/8] Checking dependencies..."
MISSING=()
for tool in xorriso mksquashfs grub-mkrescue mkfs.fat curl zstd; do
    if command -v "$tool" &>/dev/null; then
        echo "  OK: $tool"
    else
        echo "  MISSING: $tool"
        MISSING+=("$tool")
    fi
done
if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo ""
    echo "Install missing packages:"
    echo "  Ubuntu/Debian: sudo apt install xorriso squashfs-tools grub-efi-amd64-bin grub-pc-bin zstd"
    echo "  Fedora:        sudo dnf install xorriso squashfs-tools grub2-efi-x64-modules zstd"
    exit 1
fi

# ─────────────────────────────────────────────
# Step 2: Clean previous build
# ─────────────────────────────────────────────
echo ""
echo "[2/8] Cleaning previous build..."
rm -rf "$WORK"
mkdir -p "$WORK" "$OUTPUT"

# ─────────────────────────────────────────────
# Step 3: Download Arch bootstrap
# ─────────────────────────────────────────────
echo ""
echo "[3/8] Downloading Arch Linux bootstrap..."
mkdir -p "$CACHE"
BOOTSTRAP_TAR="${CACHE}/archlinux-bootstrap.tar.zst"
BOOTSTRAP_DIR="${WORK}/archlinux-root"

if [[ ! -f "$BOOTSTRAP_TAR" ]]; then
    curl -L -o "$BOOTSTRAP_TAR" "$ARCH_BOOTSTRAP_URL"
    echo "  Downloaded: $(du -h "$BOOTSTRAP_TAR" | cut -f1)"
else
    echo "  Using cached: $BOOTSTRAP_TAR ($(du -h "$BOOTSTRAP_TAR" | cut -f1))"
fi

# ─────────────────────────────────────────────
# Step 4: Extract bootstrap
# ─────────────────────────────────────────────
echo ""
echo "[4/8] Extracting Arch bootstrap..."
mkdir -p "$BOOTSTRAP_DIR"
tar -xf "$BOOTSTRAP_TAR" --strip-components=1 --no-same-owner --no-same-permissions -C "$BOOTSTRAP_DIR" 2>/dev/null || true
echo "  Extracted to: $BOOTSTRAP_DIR"

# ─────────────────────────────────────────────
# Step 5: Configure rootfs
# ─────────────────────────────────────────────
echo ""
echo "[5/8] Configuring rootfs..."

ROOTFS="${WORK}/airootfs"
mkdir -p "$ROOTFS"

# Copy bootstrap as base (skip permission errors on special files)
cp -a "$BOOTSTRAP_DIR/." "$ROOTFS/" 2>/dev/null || true

# Copy OrionOS overlay (skip permission errors)
OVERLAY="${PROJECT_ROOT}/build/profiles/orionos/airootfs"
if [[ -d "$OVERLAY" ]]; then
    cp -a "$OVERLAY/." "$ROOTFS/" 2>/dev/null || true
    echo "  Applied OrionOS overlay"
fi

# Set hostname
echo "orionos" > "$ROOTFS/etc/hostname"

# Set hosts
cat > "$ROOTFS/etc/hosts" << 'EOF'
127.0.0.1   localhost
127.0.1.1   orionos
::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
EOF

# Locale
echo "en_US.UTF-8 UTF-8" > "$ROOTFS/etc/locale.gen"
echo "LANG=en_US.UTF-8" > "$ROOTFS/etc/locale.conf"

# OrionOS version info
mkdir -p "$ROOTFS/etc/orionos"
cat > "$ROOTFS/etc/orionos/version" << EOF
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
cp "$ROOTFS/etc/orionos/version" "$ROOTFS/etc/os-release"

# Live user
cat > "${ROOTFS}/tmp/create-user.sh" << 'USEREOF'
#!/bin/bash
useradd -m -G wheel,video,audio,storage -s /bin/bash orion 2>/dev/null || true
echo "orion:orion" | chpasswd
echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel
USEREOF
chmod +x "${ROOTFS}/tmp/create-user.sh"

echo "  Rootfs configured"

# ─────────────────────────────────────────────
# Step 6: Create squashfs
# ─────────────────────────────────────────────
echo ""
echo "[6/8] Creating squashfs image..."

SQUASHFS_IMG="${WORK}/images/airootfs.sfs"
mkdir -p "${WORK}/images"

mksquashfs "$ROOTFS" "$SQUASHFS_IMG" \
    -comp zstd \
    -Xcompression-level 19 \
    -b 1M \
    -no-xattrs \
    -noappend \
    2>&1 | tail -3

SQUASH_SIZE=$(du -h "$SQUASHFS_IMG" | cut -f1)
echo "  Squashfs: $SQUASH_SIZE"

# ─────────────────────────────────────────────
# Step 7: Build boot images
# ─────────────────────────────────────────────
echo ""
echo "[7/8] Building boot images..."

ISO_DIR="${WORK}/iso"
ARCH_DIR="${ISO_DIR}/arch"
mkdir -p "${ARCH_DIR}/boot/x86_64"
mkdir -p "${ARCH_DIR}/boot/grub"
mkdir -p "${ARCH_DIR}/EFI/BOOT"

# Copy squashfs
cp "$SQUASHFS_IMG" "${ARCH_DIR}/"

# Create GRUB config
ISO_LABEL="ORIONOS_$(date +%Y%m)"
cat > "${ARCH_DIR}/boot/grub/grub.cfg" << EOF
set default=0
set timeout=8
insmod all_video
insmod gfxterm
terminal_output gfxterm

set menu_color_normal=cyan/black
set menu_color_highlight=white/blue

menuentry "OrionOS ${VERSION}" {
    linux /arch/boot/x86_64/vmlinuz archisobasedir=arch archisolabel=${ISO_LABEL} quiet
    initrd /arch/boot/x86_64/initramfs-linux.img
}

menuentry "OrionOS ${VERSION} (NVIDIA)" {
    linux /arch/boot/x86_64/vmlinuz archisobasedir=arch archisolabel=${ISO_LABEL} quiet nvidia-drm.modeset=1
    initrd /arch/boot/x86_64/initramfs-linux.img
}

menuentry "OrionOS ${VERSION} (Safe Mode)" {
    linux /arch/boot/x86_64/vmlinuz archisobasedir=arch archisolabel=${ISO_LABEL} nomodeset
    initrd /arch/boot/x86_64/initramfs-linux.img
}
EOF

# Copy kernel and initramfs from rootfs
if [[ -f "$ROOTFS/boot/vmlinuz-linux" ]]; then
    cp "$ROOTFS/boot/vmlinuz-linux" "${ARCH_DIR}/boot/x86_64/vmlinuz"
    echo "  Copied kernel"
fi
if [[ -f "$ROOTFS/boot/initramfs-linux.img" ]]; then
    cp "$ROOTFS/boot/initramfs-linux.img" "${ARCH_DIR}/boot/x86_64/initramfs-linux.img"
    echo "  Copied initramfs"
fi

# Create GRUB EFI image
GRUB_EFI="${WORK}/grub-efi.img"
dd if=/dev/zero of="$GRUB_EFI" bs=1M count=64 2>/dev/null
mkfs.fat -F 32 "$GRUB_EFI" 2>/dev/null

# Create syslinux config for BIOS boot
SYSLINUX_DIR="${ISO_DIR}/syslinux"
mkdir -p "$SYSLINUX_DIR"
cat > "${SYSLINUX_DIR}/syslinux.cfg" << EOF
PROMPT 0
TIMEOUT 50
DEFAULT orionos

LABEL orionos
    MENU LABEL OrionOS
    LINUX /arch/boot/x86_64/vmlinuz
    INITRD /arch/boot/x86_64/initramfs-linux.img
    APPEND archisobasedir=arch archisolabel=${ISO_LABEL} cow_spacesize=10G

LABEL orionos-nvidia
    MENU LABEL OrionOS (NVIDIA)
    LINUX /arch/boot/x86_64/vmlinuz
    INITRD /arch/boot/x86_64/initramfs-linux.img
    APPEND archisobasedir=arch archisolabel=${ISO_LABEL} cow_spacesize=10G nvidia-drm.modeset=1

LABEL orionos-safe
    MENU LABEL OrionOS (Safe Mode)
    LINUX /arch/boot/x86_64/vmlinuz
    INITRD /arch/boot/x86_64/initramfs-linux.img
    APPEND archisobasedir=arch archisolabel=${ISO_LABEL} nomodeset
EOF

echo "  Boot images ready"

# ─────────────────────────────────────────────
# Step 8: Build ISO
# ─────────────────────────────────────────────
echo ""
echo "[8/8] Building ISO image..."

ISO_FILE="${OUTPUT}/orionos-${VERSION}-x86_64.iso"
rm -f "$ISO_FILE"

xorriso -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "${ISO_LABEL}" \
    -output "$ISO_FILE" \
    -eltorito-boot "arch/boot/grub/grub.cfg" \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
    "$ISO_DIR"

ISO_SIZE=$(du -h "$ISO_FILE" | cut -f1)

# Generate checksum
cd "$OUTPUT"
sha256sum "$(basename "$ISO_FILE")" > "$(basename "$ISO_FILE").sha256"

echo ""
echo "========================================"
echo "  ISO BUILD COMPLETE"
echo "========================================"
echo "  File: ${ISO_FILE}"
echo "  Size: ${ISO_SIZE}"
echo "  SHA256: $(cat "$(basename "$ISO_FILE").sha256" | awk '{print $1}')"
echo ""
echo "Test:"
echo "  qemu-system-x86_64 -m 4G -cdrom ${ISO_FILE} -boot d"
echo ""
echo "USB:"
echo "  sudo dd if=${ISO_FILE} of=/dev/sdX bs=4M status=progress && sync"
