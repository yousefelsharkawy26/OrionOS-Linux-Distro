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
echo "╔══════════════════════════════════════════════════════════╗"
echo "║         OrionOS ISO Build System                        ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  Version: ${VERSION}"
echo "║  Profile: ${PROFILE}"
echo "║  Arch:    ${ARCH}"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ─────────────────────────────────────────────
# Check prerequisites
# ─────────────────────────────────────────────
echo -e "${YELLOW}[1/4]${NC} Checking prerequisites..."

if ! command -v docker &>/dev/null; then
    echo -e "${RED}ERROR: Docker is not installed.${NC}"
    echo "Install Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

if ! docker info &>/dev/null; then
    echo -e "${RED}ERROR: Docker daemon is not running.${NC}"
    echo "Start Docker: sudo systemctl start docker"
    exit 1
fi

echo -e "${GREEN}  ✓ Docker is ready${NC}"

# ─────────────────────────────────────────────
# Build Docker image
# ─────────────────────────────────────────────
echo -e "${YELLOW}[2/4]${NC} Building Docker image..."

docker build -t "$IMAGE_NAME" "$PROJECT_ROOT"

echo -e "${GREEN}  ✓ Docker image built${NC}"

# ─────────────────────────────────────────────
# Run ISO build in container
# ─────────────────────────────────────────────
echo -e "${YELLOW}[3/4]${NC} Building ISO (this will take a while)..."

mkdir -p "${PROJECT_ROOT}/build/iso"

docker run --rm \
    --privileged \
    -e VERSION="$VERSION" \
    -e PROFILE="$PROFILE" \
    -e ARCH="$ARCH" \
    -v "${PROJECT_ROOT}:/build/orionos" \
    -v "${PROJECT_ROOT}/build/iso:/build/orionos/build/iso" \
    "$IMAGE_NAME"

# ─────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────
echo -e "${YELLOW}[4/4]${NC} Build complete!"

ISO_FILE=$(find "${PROJECT_ROOT}/build/iso" -maxdepth 1 -name "*.iso" | head -1)
if [[ -n "$ISO_FILE" ]]; then
    ISO_SIZE=$(du -h "$ISO_FILE" | cut -f1)
    echo ""
    echo -e "${GREEN}ISO created:${NC} ${ISO_FILE}"
    echo -e "${GREEN}Size:${NC} ${ISO_SIZE}"
    echo ""
    echo "Test the ISO:"
    echo "  qemu-system-x86_64 -m 4G -cdrom ${ISO_FILE} -boot d"
    echo ""
    echo "Write to USB:"
    echo "  sudo dd if=${ISO_FILE} of=/dev/sdX bs=4M status=progress && sync"
else
    echo -e "${RED}ERROR: ISO file not found in build/iso/${NC}"
    exit 1
fi
