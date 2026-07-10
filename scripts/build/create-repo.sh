#!/bin/bash
# ==============================================================================
# OrionOS Build System - Package Repository Creator
# Creates a local pacman repository from built packages
# ==============================================================================

set -euo pipefail

# Arguments
PKG_DIR="${1:-$(pwd)/build/packages}"
REPO_DIR="${2:-$(pwd)/build/repo}"
REPO_NAME="${3:-orionos}"

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source logging
source "${SCRIPT_DIR}/logging.sh"

log_section "OrionOS Package Repository Creation"
log_info "Package directory: $PKG_DIR"
log_info "Repository directory: $REPO_DIR"
log_info "Repository name: $REPO_NAME"

# ==============================================================================
# Validate inputs
# ==============================================================================
if [[ ! -d "$PKG_DIR" ]]; then
    log_error "Package directory not found: $PKG_DIR"
    exit 1
fi

# Check for packages
shopt -s nullglob
PACKAGES=("$PKG_DIR"/*.pkg.tar.*)
shopt -u nullglob

if [[ ${#PACKAGES[@]} -eq 0 ]]; then
    log_error "No packages found in: $PKG_DIR"
    exit 1
fi

log_info "Found ${#PACKAGES[@]} packages"

# ==============================================================================
# Create repository structure
# ==============================================================================
mkdir -p "$REPO_DIR/$REPO_NAME/os/x86_64"
mkdir -p "$REPO_DIR/$REPO_NAME/os/aarch64"

# ==============================================================================
# Copy packages to repository
# ==============================================================================
log_step "Copying packages to repository"

for pkg in "${PACKAGES[@]}"; do
    pkg_name=$(basename "$pkg")
    cp "$pkg" "$REPO_DIR/$REPO_NAME/os/x86_64/"
    log_debug "Copied: $pkg_name"
done

log_info "Packages copied"

# ==============================================================================
# Create repository database
# ==============================================================================
log_step "Creating repository database"

cd "$REPO_DIR/$REPO_NAME/os/x86_64"

# Create the database
repo-add "$REPO_NAME.db.tar.gz" *.pkg.tar.*

# Create symlinks for the database
ln -sf "$REPO_NAME.db.tar.gz" "$REPO_NAME.db" 2>/dev/null || true
ln -sf "$REPO_NAME.files.tar.gz" "$REPO_NAME.files" 2>/dev/null || true

log_info "Repository database created"

# ==============================================================================
# Generate pacman configuration snippet
# ==============================================================================
log_step "Generating pacman configuration"

cat > "$REPO_DIR/$REPO_NAME.conf" << EOF
# OrionOS Local Repository
# Add this to your /etc/pacman.conf

[$REPO_NAME]
SigLevel = Optional TrustAll
Server = file://$REPO_DIR/$REPO_NAME/os/\$arch
EOF

log_info "Repository configuration: $REPO_DIR/$REPO_NAME.conf"

# ==============================================================================
# Generate repository info
# ==============================================================================
log_step "Generating repository info"

cat > "$REPO_DIR/$REPO_NAME.info" << EOF
{
    "name": "$REPO_NAME",
    "version": "0.1.0-alpha",
    "packages": $(echo "${#PACKAGES[@]}"),
    "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "path": "$REPO_DIR/$REPO_NAME/os/x86_64"
}
EOF

log_info "Repository info: $REPO_DIR/$REPO_NAME.info"

# ==============================================================================
# Summary
# ==============================================================================
log_section "Repository Creation Complete"

log_info "Repository: $REPO_NAME"
log_info "Location: $REPO_DIR/$REPO_NAME/os/x86_64"
log_info "Packages: ${#PACKAGES[@]}"
log_info "Database: $REPO_NAME.db.tar.gz"

echo ""
log_info "To use this repository, add to /etc/pacman.conf:"
echo "  [$REPO_NAME]"
echo "  Server = file://$REPO_DIR/$REPO_NAME/os/\$arch"
