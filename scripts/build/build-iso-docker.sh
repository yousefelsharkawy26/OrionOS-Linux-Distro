#!/bin/bash
# ==============================================================================
# OrionOS ISO Build - Docker Entrypoint
# Builds ISO inside Arch Linux container
# ==============================================================================

set -euo pipefail

BUILD_DIR="/build/orionos"
ISO_OUTPUT="${BUILD_DIR}/build/iso"
VERSION="${VERSION:-1.0.0}"
PROFILE="${PROFILE:-default}"
ARCH="${ARCH:-x86_64}"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║           OrionOS ISO Builder (Docker)                  ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  Version:  ${VERSION}"
echo "║  Profile:  ${PROFILE}"
echo "║  Arch:     ${ARCH}"
echo "║  Output:   ${ISO_OUTPUT}"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# ─────────────────────────────────────────────
# Step 1: Update system and enable multilib
# ─────────────────────────────────────────────
echo "[1/6] Updating system..."
sudo pacman -Syu --noconfirm

# Enable multilib
if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
    echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" | sudo tee -a /etc/pacman.conf
    sudo pacman -Sy
fi

# ─────────────────────────────────────────────
# Step 2: Configure pacman for build
# ─────────────────────────────────────────────
echo "[2/6] Configuring pacman..."

# Create pacman.conf for the build
sudo tee /etc/pacman.conf << 'EOF'
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
EOF

sudo pacman -Sy

# ─────────────────────────────────────────────
# Step 3: Build OrionOS packages
# ─────────────────────────────────────────────
echo "[3/6] Building OrionOS packages..."

BUILD_PACKAGES="${BUILD_DIR}/build/packages"
mkdir -p "${BUILD_PACKAGES}"

# Build each package
for pkg_dir in "${BUILD_DIR}"/packages/core/*/; do
    if [[ -f "${pkg_dir}/PKGBUILD" ]]; then
        pkg_name=$(basename "$pkg_dir")
        echo "  → Building ${pkg_name}..."
        cd "$pkg_dir"
        makepkg -s --noconfirm --cleanbuild 2>/dev/null || echo "  ⚠ Failed to build ${pkg_name}"
        mv *.pkg.tar.* "${BUILD_PACKAGES}/" 2>/dev/null || true
    fi
done

for pkg_dir in "${BUILD_DIR}"/packages/extra/*/; do
    if [[ -f "${pkg_dir}/PKGBUILD" ]]; then
        pkg_name=$(basename "$pkg_dir")
        echo "  → Building ${pkg_name}..."
        cd "$pkg_dir"
        makepkg -s --noconfirm --cleanbuild 2>/dev/null || echo "  ⚠ Failed to build ${pkg_name}"
        mv *.pkg.tar.* "${BUILD_PACKAGES}/" 2>/dev/null || true
    fi
done

# ─────────────────────────────────────────────
# Step 4: Create local repo
# ─────────────────────────────────────────────
echo "[4/6] Creating package repository..."

REPO_DIR="${BUILD_DIR}/build/repo/orionos/os/x86_64"
mkdir -p "$REPO_DIR"

if ls "${BUILD_PACKAGES}/"*.pkg.tar.* &>/dev/null; then
    cp "${BUILD_PACKAGES}/"*.pkg.tar.* "$REPO_DIR/"
    cd "$REPO_DIR"
    repo-add orionos.db.tar.gz *.pkg.tar.* 2>/dev/null || true
    cd "$BUILD_DIR"
else
    echo "  ℹ No packages built, skipping repo creation"
fi

# ─────────────────────────────────────────────
# Step 5: Build ISO with archiso
# ─────────────────────────────────────────────
echo "[5/6] Building ISO image..."

PROFILE_DIR="${BUILD_DIR}/build/profiles/orionos"
WORK_DIR="${BUILD_DIR}/build/work"
OUT_DIR="${BUILD_DIR}/build/iso"

mkdir -p "$WORK_DIR" "$OUT_DIR"

# Update profiledef with correct label
ISO_LABEL="ORIONOS_$(date +%Y%m)"
sed -i "s|ORIONOS_[0-9]*|${ISO_LABEL}|g" "${PROFILE_DIR}/profiledef.sh"

# Clean old work dir
rm -rf "${WORK_DIR:?}"/*

# Build with mkarchiso
sudo mkarchiso -v \
    -w "$WORK_DIR" \
    -o "$OUT_DIR" \
    "$PROFILE_DIR"

# ─────────────────────────────────────────────
# Step 6: Generate checksums
# ─────────────────────────────────────────────
echo "[6/6] Generating checksums..."

cd "$OUT_DIR"
ISO_FILE=$(find . -maxdepth 1 -name "*.iso" | head -1)

if [[ -n "$ISO_FILE" ]]; then
    sha256sum "$ISO_FILE" > "${ISO_FILE}.sha256"
    sha512sum "$ISO_FILE" > "${ISO_FILE}.sha512"
    md5sum "$ISO_FILE" > "${ISO_FILE}.md5"

    ISO_SIZE=$(du -h "$ISO_FILE" | cut -f1)

    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║               ISO BUILD COMPLETE                        ║"
    echo "╠══════════════════════════════════════════════════════════╣"
    echo "║  File:  ${ISO_FILE}"
    echo "║  Size:  ${ISO_SIZE}"
    echo "║  SHA256: $(cat "${ISO_FILE}.sha256" | awk '{print $1}')"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    echo "To test: qemu-system-x86_64 -m 4G -cdrom ${OUT_DIR}/${ISO_FILE} -boot d"
else
    echo "ERROR: ISO file not found!"
    exit 1
fi
