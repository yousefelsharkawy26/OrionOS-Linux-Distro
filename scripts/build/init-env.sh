#!/bin/bash
# =============================================================================
# OrionOS Build Environment Initialization
# Initializes the build environment with required dependencies
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ARCH="${1:-x86_64}"

source "${PROJECT_ROOT}/scripts/build/logging.sh"

log_info "Initializing OrionOS build environment for ${ARCH}..."

# Required build dependencies
BUILD_DEPS=(
    # Base tools
    "base-devel"
    "archiso"
    "git"
    "sudo"

    # Kernel build
    "bc"
    "cpio"
    "gettext"
    "libelf"
    "pahole"
    "perl"
    "python"
    "tar"
    "xz"

    # Filesystem tools
    "btrfs-progs"
    "squashfs-tools"
    "e2fsprogs"
    "dosfstools"

    # Boot tools
    "efibootmgr"
    "efitools"
    "grub"
    "libisoburn"
    "mtools"
    "os-prober"
    "shim"

    # Signing
    "openssl"
    "gnupg"

    # Compression
    "lz4"
    "lzo"
    "p7zip"
    "zstd"

    # Network
    "wget"
    "curl"

    # Containers
    "docker"
    "podman"

    # Python for build scripts
    "python-yaml"
    "python-requests"
    "python-jinja"
    "python-psutil"
)

# Check if running on Arch Linux
if [[ ! -f /etc/arch-release ]]; then
    log_warn "Not running on Arch Linux. Build environment may need manual setup."
fi

# Install dependencies
log_info "Installing build dependencies..."
if command -v pacman &>/dev/null; then
    sudo pacman -S --needed --noconfirm "${BUILD_DEPS[@]}" || {
        log_error "Failed to install build dependencies"
        exit 1
    }
else
    log_error "pacman not found. This script requires an Arch-based system."
    exit 1
fi

# Create build directories
log_info "Creating build directories..."
mkdir -p "${PROJECT_ROOT}/build"/{iso,packages,kernel,repo,logs,sources}
mkdir -p "${PROJECT_ROOT}/build/packages"/{core,extra,community}

# Setup pacman keyring for package signing
log_info "Initializing pacman keyring..."
sudo pacman-key --init
sudo pacman-key --populate archlinux

# Setup build user if not exists
if ! id -u builduser &>/dev/null 2>&1; then
    log_info "Creating build user..."
    sudo useradd -m -G wheel -s /bin/bash builduser || true
    echo "builduser ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers.d/builduser >/dev/null
fi

# Verify archiso installation
if [[ ! -d /usr/share/archiso ]]; then
    log_error "archiso not properly installed"
    exit 1
fi

# Copy archiso base for customization
log_info "Setting up archiso base..."
cp -r /usr/share/archiso/configs/releng/ "${PROJECT_ROOT}/build/archiso-base/" || true

log_success "Build environment initialized successfully!"
log_info "You can now run: make all"
