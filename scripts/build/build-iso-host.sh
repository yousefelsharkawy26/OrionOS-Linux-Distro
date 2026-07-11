#!/bin/bash
# ==============================================================================
# OrionOS ISO Build - Host Wrapper
# Run this script from any Linux system to build the ISO
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

VERSION="${VERSION:-1.0.0}"
PROFILE="${PROFILE:-default}"
ARCH="${ARCH:-x86_64}"
IMAGE_NAME="orionos-builder"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
echo "=== OrionOS ISO Build ==="
echo "  Version: ${VERSION}"
echo "  Profile: ${PROFILE}"
echo "  Arch:    ${ARCH}"
echo -e "${NC}"

# ─────────────────────────────────────────────
# Check prerequisites
# ─────────────────────────────────────────────
echo -e "${YELLOW}[1/3]${NC} Checking prerequisites..."

if ! command -v docker &>/dev/null; then
    echo -e "${RED}ERROR: Docker is not installed.${NC}"
    echo "Install: https://docs.docker.com/get-docker/"
    exit 1
fi

if ! docker info &>/dev/null 2>&1; then
    echo -e "${RED}ERROR: Docker daemon is not running.${NC}"
    echo "Start: sudo systemctl start docker"
    exit 1
fi

echo -e "${GREEN}  Docker ready${NC}"

# ─────────────────────────────────────────────
# Build Docker image (just the tools, no project copy)
# ─────────────────────────────────────────────
echo -e "${YELLOW}[2/3]${NC} Building Docker image..."

docker build -t "$IMAGE_NAME" "$PROJECT_ROOT"

echo -e "${GREEN}  Image built${NC}"

# ─────────────────────────────────────────────
# Run ISO build in container (mount project)
# ─────────────────────────────────────────────
echo -e "${YELLOW}[3/3]${NC} Building ISO (this takes a while)..."

mkdir -p "${PROJECT_ROOT}/build/iso"

docker run --rm \
    --privileged \
    -e VERSION="$VERSION" \
    -e PROFILE="$PROFILE" \
    -e ARCH="$ARCH" \
    -v "${PROJECT_ROOT}:/build/orionos" \
    "$IMAGE_NAME" \
    bash -c '
        set -euo pipefail
        cd /build/orionos

        echo "[1/6] Configuring pacman..."
        if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
            echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf
            pacman -Sy --noconfirm
        fi

        echo "[2/6] Building packages..."
        BUILD_PACKAGES="build/packages"
        mkdir -p "$BUILD_PACKAGES"

        for pkg_dir in packages/core/*/; do
            if [ -f "${pkg_dir}PKGBUILD" ]; then
                pkg_name=$(basename "$pkg_dir")
                echo "  Building ${pkg_name}..."
                (cd "$pkg_dir" && makepkg -s --noconfirm --cleanbuild 2>/dev/null && mv *.pkg.tar.* "../../${BUILD_PACKAGES}/" 2>/dev/null) || echo "  WARN: ${pkg_name} skipped"
            fi
        done
        for pkg_dir in packages/extra/*/; do
            if [ -f "${pkg_dir}PKGBUILD" ]; then
                pkg_name=$(basename "$pkg_dir")
                echo "  Building ${pkg_name}..."
                (cd "$pkg_dir" && makepkg -s --noconfirm --cleanbuild 2>/dev/null && mv *.pkg.tar.* "../../${BUILD_PACKAGES}/" 2>/dev/null) || echo "  WARN: ${pkg_name} skipped"
            fi
        done

        echo "[3/6] Creating package repository..."
        REPO_DIR="build/repo/orionos/os/x86_64"
        mkdir -p "$REPO_DIR"
        if ls ${BUILD_PACKAGES}/*.pkg.tar.* 2>/dev/null; then
            cp ${BUILD_PACKAGES}/*.pkg.tar.* "$REPO_DIR/"
            (cd "$REPO_DIR" && repo-add orionos.db.tar.gz *.pkg.tar.* 2>/dev/null) || true
        fi

        echo "[4/6] Preparing archiso profile..."
        PROFILE_DIR="build/profiles/orionos"
        WORK_DIR="build/work"
        rm -rf "${WORK_DIR:?}"/*
        mkdir -p "$WORK_DIR" "build/iso"

        ISO_LABEL="ORIONOS_$(date +%Y%m)"
        sed -i "s|ORIONOS_[0-9]*|${ISO_LABEL}|g" "${PROFILE_DIR}/profiledef.sh"

        echo "[5/6] Building ISO with mkarchiso..."
        mkarchiso -v -w "$WORK_DIR" -o "build/iso" "$PROFILE_DIR"

        echo "[6/6] Generating checksums..."
        cd build/iso
        ISO_FILE=$(find . -maxdepth 1 -name "*.iso" | head -1)
        if [ -n "$ISO_FILE" ]; then
            sha256sum "$ISO_FILE" > "${ISO_FILE}.sha256"
            sha512sum "$ISO_FILE" > "${ISO_FILE}.sha512"
            md5sum "$ISO_FILE" > "${ISO_FILE}.md5"
            ISO_SIZE=$(du -h "$ISO_FILE" | cut -f1)
            echo ""
            echo "=== ISO BUILD COMPLETE ==="
            echo "  File: ${ISO_FILE}"
            echo "  Size: ${ISO_SIZE}"
            echo "  SHA256: $(head -c 64 ${ISO_FILE}.sha256)"
        else
            echo "ERROR: ISO file not found!"
            exit 1
        fi
    '

# ─────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────
echo ""
ISO_FILE=$(find "${PROJECT_ROOT}/build/iso" -maxdepth 1 -name "*.iso" | head -1)
if [[ -n "$ISO_FILE" ]]; then
    ISO_SIZE=$(du -h "$ISO_FILE" | cut -f1)
    echo -e "${GREEN}ISO created:${NC} ${ISO_FILE}"
    echo -e "${GREEN}Size:${NC} ${ISO_SIZE}"
    echo ""
    echo "Test: qemu-system-x86_64 -m 4G -cdrom ${ISO_FILE} -boot d"
    echo "USB:  sudo dd if=${ISO_FILE} of=/dev/sdX bs=4M status=progress && sync"
else
    echo -e "${RED}ERROR: ISO not found in build/iso/${NC}"
    exit 1
fi
