#!/bin/bash
# ==============================================================================
# OrionOS Build System - Package Builder
# Builds all OrionOS packages from PKGBUILD definitions
# ==============================================================================

set -euo pipefail

# Arguments
PKG_DIR="${1:-$(pwd)/build/packages}"
ARCH="${2:-x86_64}"
PROFILE="${3:-default}"

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source logging
source "${SCRIPT_DIR}/logging.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_section "OrionOS Package Build"
log_info "Package directory: $PKG_DIR"
log_info "Architecture: $ARCH"
log_info "Profile: $PROFILE"

# Create package output directory
mkdir -p "$PKG_DIR"

# ==============================================================================
# Package build order
# ==============================================================================
# Packages must be built in dependency order
PACKAGES=(
    "orionos-config"
    "orionos-themes"
    "orionos-utils"
    "orionos-security"
    "orionos-services"
    "orionos-desktop"
)

# Profile-specific packages
PROFILE_PACKAGES=()
case "$PROFILE" in
    gaming)
        PROFILE_PACKAGES+=("orionos-gaming")
        ;;
    developer)
        PROFILE_PACKAGES+=("orionos-devtools")
        ;;
    minimal)
        # Minimal doesn't add extra packages
        ;;
esac

# Combine
ALL_PACKAGES=("${PACKAGES[@]}" "${PROFILE_PACKAGES[@]}")

log_info "Packages to build: ${ALL_PACKAGES[*]}"

# ==============================================================================
# Build each package
# ==============================================================================
TOTAL=${#ALL_PACKAGES[@]}
CURRENT=0
FAILED_PACKAGES=()

for pkg in "${ALL_PACKAGES[@]}"; do
    CURRENT=$((CURRENT + 1))
    log_step "Building: $pkg" "$CURRENT" "$TOTAL"

    # Find PKGBUILD
    PKGBUILD_PATH=""
    for search_dir in "$PROJECT_ROOT/packages/core" "$PROJECT_ROOT/packages/extra" "$PROJECT_ROOT/packages/community"; do
        if [[ -f "$search_dir/$pkg/PKGBUILD" ]]; then
            PKGBUILD_PATH="$search_dir/$pkg/PKGBUILD"
            break
        fi
    done

    if [[ -z "$PKGBUILD_PATH" ]]; then
        log_warn "PKGBUILD not found for: $pkg"
        FAILED_PACKAGES+=("$pkg")
        continue
    fi

    PKG_SRC_DIR="$(dirname "$PKGBUILD_PATH")"
    log_info "Source: $PKG_SRC_DIR"

    # Create temporary build directory
    BUILD_TMP=$(mktemp -d)
    cp -r "$PKG_SRC_DIR"/* "$BUILD_TMP/"

    # Build the package
    cd "$BUILD_TMP"

    if makepkg -s --noconfirm --needed -c 2>&1; then
        log_info "Build successful: $pkg"

        # Move built packages to output directory
        shopt -s nullglob
        BUILT_PKGS=("$BUILD_TMP"/*.pkg.tar.*)
        shopt -u nullglob

        if [[ ${#BUILT_PKGS[@]} -gt 0 ]]; then
            for built_pkg in "${BUILT_PKGS[@]}"; do
                mv "$built_pkg" "$PKG_DIR/"
                log_info "Package: $(basename "$built_pkg")"
            done
        else
            log_warn "No package files produced for: $pkg"
        fi
    else
        log_error "Build failed: $pkg"
        FAILED_PACKAGES+=("$pkg")
    fi

    # Cleanup
    rm -rf "$BUILD_TMP"
    cd "$PROJECT_ROOT"
done

# ==============================================================================
# Summary
# ==============================================================================
log_section "Package Build Summary"

SUCCESS_COUNT=$((TOTAL - ${#FAILED_PACKAGES[@]}))
log_info "Built: $SUCCESS_COUNT/$TOTAL packages"

if [[ ${#FAILED_PACKAGES[@]} -gt 0 ]]; then
    log_warn "Failed packages:"
    for pkg in "${FAILED_PACKAGES[@]}"; do
        echo "  - $pkg"
    done
    exit 1
else
    log_info "All packages built successfully!"
    log_info "Output: $PKG_DIR"
    ls -la "$PKG_DIR"/*.pkg.tar.* 2>/dev/null || true
fi
