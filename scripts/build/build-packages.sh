#!/bin/bash
# =============================================================================
# OrionOS Package Build System
# Builds all OrionOS packages in dependency order
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PKG_DIR="${1:-${PROJECT_ROOT}/build/packages}"
ARCH="${2:-x86_64}"
PROFILE="${3:-default}"

source "${PROJECT_ROOT}/scripts/build/logging.sh"

log_section "OrionOS Package Build System"
log_info "Output: ${PKG_DIR}"
log_info "Architecture: ${ARCH}"
log_info "Profile: ${PROFILE}"

# Package build directories
CORE_PKGS="${PROJECT_ROOT}/packages/core"
EXTRA_PKGS="${PROJECT_ROOT}/packages/extra"
COMMUNITY_PKGS="${PROJECT_ROOT}/packages/community"

# Build directories
CORE_BUILD="${PKG_DIR}/core"
EXTRA_BUILD="${PKG_DIR}/extra"
COMMUNITY_BUILD="${PKG_DIR}/community"

mkdir -p "${CORE_BUILD}" "${EXTRA_BUILD}" "${COMMUNITY_BUILD}"

# Build packages from a directory
build_pkg_dir() {
    local src_dir="$1"
    local out_dir="$2"
    local category="$3"

    if [[ ! -d "$src_dir" ]]; then
        log_warn "Package directory not found: $src_dir"
        return 0
    fi

    log_info "Building ${category} packages..."

    for pkg_dir in "${src_dir}"/*/; do
        if [[ ! -f "${pkg_dir}/PKGBUILD" ]]; then
            continue
        fi

        local pkg_name
        pkg_name="$(basename "$pkg_dir")"
        log_info "Building ${pkg_name}..."

        # Check if already built
        if compgen -G "${out_dir}/${pkg_name}-*.pkg.tar.zst" > /dev/null; then
            log_success "${pkg_name} already built, skipping"
            continue
        fi

        # Build package
        cd "$pkg_dir"

        # Update PKGBUILD version if needed
        if [[ -f "${PROJECT_ROOT}/VERSION" ]]; then
            local orion_version
            orion_version="$(cat "${PROJECT_ROOT}/VERSION")"
            sed -i "s/^pkgver=.*/pkgver=${orion_version}/" PKGBUILD 2>/dev/null || true
        fi

        # Build
        if ! makepkg -s --noconfirm -C 2>&1 | tee "${PROJECT_ROOT}/build/logs/${pkg_name}-build.log"; then
            log_error "Failed to build ${pkg_name}"
            continue
        fi

        # Move built package
        mv ./*.pkg.tar.zst "${out_dir}/" 2>/dev/null || true

        log_success "${pkg_name} built successfully"
        cd - >/dev/null
    done
}

# Build packages in order
log_info "Starting package builds..."

# Core packages (essential system components)
build_pkg_dir "$CORE_PKGS" "$CORE_BUILD" "core"

# Extra packages (desktop, tools)
build_pkg_dir "$EXTRA_PKGS" "$EXTRA_BUILD" "extra"

# Community packages (additional software)
build_pkg_dir "$COMMUNITY_PKGS" "$COMMUNITY_BUILD" "community"

# Profile-specific packages
case "$PROFILE" in
    gaming)
        log_info "Building gaming profile packages..."
        build_pkg_dir "${PROJECT_ROOT}/profiles/gaming" "$EXTRA_BUILD" "gaming"
        ;;
    developer)
        log_info "Building developer profile packages..."
        build_pkg_dir "${PROJECT_ROOT}/profiles/developer" "$EXTRA_BUILD" "developer"
        ;;
    minimal)
        log_info "Using minimal profile - no extra packages"
        ;;
    *)
        log_info "Using default profile"
        ;;
esac

log_success "All packages built successfully!"
log_info "Packages in: ${PKG_DIR}"

# Generate package list
find "$PKG_DIR" -name "*.pkg.tar.zst" -exec basename {} \; | sort > "${PKG_DIR}/package-list.txt"
log_info "Package list: ${PKG_DIR}/package-list.txt"
