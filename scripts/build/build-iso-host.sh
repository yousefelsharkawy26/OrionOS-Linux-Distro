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

echo "=== OrionOS ISO Build ==="
echo "  Version: ${VERSION}"
echo "  Profile: ${PROFILE}"
echo "  Arch:    ${ARCH}"
echo ""

# Check prerequisites
echo "[1/3] Checking prerequisites..."
if ! command -v docker &>/dev/null; then
    echo "ERROR: Docker is not installed."
    exit 1
fi
if ! docker info &>/dev/null 2>&1; then
    echo "ERROR: Docker daemon is not running."
    exit 1
fi
echo "  Docker ready"

# Build Docker image
echo "[2/3] Building Docker image..."
docker build -t "$IMAGE_NAME" "$PROJECT_ROOT"
echo "  Image built"

# Run ISO build in container
echo "[3/3] Building ISO..."
mkdir -p "${PROJECT_ROOT}/build/iso"

docker run --rm \
    --privileged \
    --tmpfs /tmp:rw,size=4G \
    -e VERSION="$VERSION" \
    -e PROFILE="$PROFILE" \
    -e ARCH="$ARCH" \
    -v "${PROJECT_ROOT}:/build/orionos" \
    "$IMAGE_NAME" \
    bash -c '
        set -euo pipefail
        cd /build/orionos

        echo "[1/3] Configuring pacman..."
        sed -i "s|ORIONOS_[0-9]*|ORIONOS_$(date +%Y%m)|g" build/profiles/orionos/profiledef.sh

        echo "[2/3] Cleaning previous build..."
        rm -rf build/work/*
        mkdir -p build/work build/iso

        echo "[3/3] Building ISO with mkarchiso..."
        mkarchiso -v \
            -w build/work \
            -o build/iso \
            build/profiles/orionos

        echo ""
        echo "=== BUILD COMPLETE ==="
        cd build/iso
        ISO_FILE=$(find . -maxdepth 1 -name "*.iso" | head -1)
        if [ -n "$ISO_FILE" ]; then
            sha256sum "$ISO_FILE" > "${ISO_FILE}.sha256"
            ISO_SIZE=$(du -h "$ISO_FILE" | cut -f1)
            echo "  File: ${ISO_FILE}"
            echo "  Size: ${ISO_SIZE}"
            echo "  SHA256: $(head -c 64 ${ISO_FILE}.sha256)"
        else
            echo "ERROR: ISO file not found!"
            exit 1
        fi
    '

echo ""
ISO_FILE=$(find "${PROJECT_ROOT}/build/iso" -maxdepth 1 -name "*.iso" | head -1)
if [[ -n "$ISO_FILE" ]]; then
    ISO_SIZE=$(du -h "$ISO_FILE" | cut -f1)
    echo "ISO created: ${ISO_FILE}"
    echo "Size: ${ISO_SIZE}"
    echo ""
    echo "Test: qemu-system-x86_64 -m 4G -cdrom ${ISO_FILE} -boot d"
    echo "USB:  sudo dd if=${ISO_FILE} of=/dev/sdX bs=4M status=progress && sync"
else
    echo "ERROR: ISO not found in build/iso/"
    exit 1
fi
