#!/usr/bin/env bash
# ==============================================================================
# OrionOS ISO Builder - Self-contained wrapper
# Works on any machine with Docker installed and running
# ==============================================================================
# Usage:
#   ./build-orionos-iso.sh
#   VERSION=1.0.0 PROFILE=gaming ./build-orionos-iso.sh
#
# Requirements:
#   - Docker installed and running (sudo systemctl start docker)
#   - ~5 GB free disk space
#   - Network access (downloads Arch packages inside container)
#
# Output:
#   build/iso/orionos-1.0.0-x86_64.iso
#   build/iso/orionos-1.0.0-x86_64.iso.sha256
# ==============================================================================
set -euo pipefail

VERSION="${VERSION:-1.0.0}"
PROFILE="${PROFILE:-default}"
ARCH="${ARCH:-x86_64}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${REPO_DIR}"

echo "=== OrionOS ISO Build ==="
echo "  Repo:    ${REPO_DIR}"
echo "  Version: ${VERSION}"
echo "  Profile: ${PROFILE}"
echo "  Arch:    ${ARCH}"
echo ""

# --- 1. Prerequisite checks --------------------------------------------------
echo "[1/4] Checking prerequisites..."
if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: Docker is not installed."
    echo "  Install: https://docs.docker.com/get-docker/"
    exit 1
fi
if ! docker info >/dev/null 2>&1; then
    echo "ERROR: Docker daemon is not running."
    echo "  Start: sudo systemctl start docker"
    exit 1
fi
echo "  Docker ready: $(docker --version)"

FREE_MB=$(df -m "${REPO_DIR}" | awk 'NR==2 {print $4}')
if [ "${FREE_MB}" -lt 5120 ]; then
    echo "  WARN: Only ${FREE_MB} MB free; build needs ~5 GB"
else
    echo "  Disk OK: ${FREE_MB} MB free"
fi

# --- 2. Build Docker image ---------------------------------------------------
echo ""
echo "[2/4] Building Docker image..."
docker build -t orionos-builder .
echo "  Image built"

# --- 3. Build ISO inside container -------------------------------------------
echo ""
echo "[3/4] Building ISO with mkarchiso..."
mkdir -p build/iso build/work

docker run --rm \
    --privileged \
    --tmpfs /tmp:rw,size=4G \
    -e VERSION="${VERSION}" \
    -e PROFILE="${PROFILE}" \
    -e ARCH="${ARCH}" \
    -v "${REPO_DIR}:/build/orionos" \
    orionos-builder \
    bash -c '
        set -euo pipefail
        cd /build/orionos

        echo "  [container] Updating ISO label..."
        sed -i "s|ORIONOS_[0-9]*|ORIONOS_$(date +%Y%m)|g" build/profiles/orionos/profiledef.sh

        echo "  [container] Cleaning previous build..."
        rm -rf build/work/*
        mkdir -p build/work build/iso

        echo "  [container] Running mkarchiso..."
        mkarchiso -v \
            -w build/work \
            -o build/iso \
            build/profiles/orionos

        echo ""
        echo "=== CONTAINER BUILD COMPLETE ==="
        cd build/iso
        ISO_FILE=$(find . -maxdepth 1 -name "*.iso" | head -1)
        if [ -n "${ISO_FILE}" ]; then
            sha256sum "${ISO_FILE}" > "${ISO_FILE}.sha256"
            ISO_SIZE=$(du -h "${ISO_FILE}" | cut -f1)
            echo "  File:   ${ISO_FILE}"
            echo "  Size:   ${ISO_SIZE}"
            echo "  SHA256: $(head -c 64 ${ISO_FILE}.sha256)"
        else
            echo "ERROR: ISO not found in build/iso/"
            exit 1
        fi
    '

# --- 4. Report ----------------------------------------------------------------
echo ""
echo "[4/4] Done."
ISO_FILE=$(find "${REPO_DIR}/build/iso" -maxdepth 1 -name "*.iso" | head -1)
if [ -n "${ISO_FILE}" ]; then
    ISO_SIZE=$(du -h "${ISO_FILE}" | cut -f1)
    echo ""
    echo "========================================"
    echo "  ISO:  ${ISO_FILE}"
    echo "  Size: ${ISO_SIZE}"
    echo "========================================"
    echo ""
    echo "Test in QEMU:"
    echo "  qemu-system-x86_64 -m 4G -cdrom ${ISO_FILE} -boot d"
    echo ""
    echo "Write to USB:"
    echo "  sudo dd if=${ISO_FILE} of=/dev/sdX bs=4M status=progress && sync"
    echo ""
    echo "Live user: orion / orion"
else
    echo "ERROR: ISO not produced. Check build/work/ for logs."
    exit 1
fi
