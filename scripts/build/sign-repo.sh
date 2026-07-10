#!/bin/bash
# ==============================================================================
# OrionOS Build System - Repository Signing
# Signs the package database with GPG for secure distribution
# ==============================================================================

set -euo pipefail

# Arguments
REPO_DIR="${1:-$(pwd)/build/repo}"
GPG_KEY="${GPG_KEY:-}"
REPO_NAME="${2:-orionos}"

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source logging
source "${SCRIPT_DIR}/logging.sh"

log_section "OrionOS Repository Signing"
log_info "Repository directory: $REPO_DIR"
log_info "Repository name: $REPO_NAME"

# ==============================================================================
# Check GPG key
# ==============================================================================
log_step "Checking GPG configuration"

if [[ -z "$GPG_KEY" ]]; then
    # Try to find an OrionOS key
    ORIONOS_KEY=$(gpg --list-secret-keys --with-colons 2>/dev/null | \
        awk -F: '/^sec/ { print $5 }' | head -1 || true)
    
    if [[ -n "$ORIONOS_KEY" ]]; then
        GPG_KEY="$ORIONOS_KEY"
        log_info "Using GPG key: $GPG_KEY"
    else
        log_warn "No GPG key configured"
        log_info "Set GPG_KEY environment variable or generate a key:"
        echo "  gpg --full-generate-key"
        echo "  export GPG_KEY=<key_id>"
        
        read -p "Generate a new GPG key? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            gpg --batch --passphrase '' \
                --quick-gen-key "OrionOS Build <build@orionos.org>" \
                default default 2>/dev/null || \
            gpg --full-generate-key
            
            GPG_KEY=$(gpg --list-secret-keys --with-colons 2>/dev/null | \
                awk -F: '/^sec/ { print $5 }' | head -1 || true)
        else
            log_info "Skipping signing - repository will be unsigned"
            exit 0
        fi
    fi
fi

# ==============================================================================
# Sign repository database
# ==============================================================================
log_step "Signing repository database"

REPO_PATH="$REPO_DIR/$REPO_NAME/os/x86_64"

if [[ ! -d "$REPO_PATH" ]]; then
    log_error "Repository not found: $REPO_PATH"
    exit 1
fi

cd "$REPO_PATH"

# Sign the database
if [[ -f "$REPO_NAME.db.tar.gz" ]]; then
    gpg --detach-sign --use-agent -u "$GPG_KEY" \
        --no-armor -o "$REPO_NAME.db.sig" \
        "$REPO_NAME.db.tar.gz"
    log_info "Signed: $REPO_NAME.db.tar.gz"
fi

# Sign packages
log_step "Signing packages"

SIGNED_COUNT=0
for pkg in *.pkg.tar.*; do
    if [[ -f "$pkg" && ! -f "$pkg.sig" ]]; then
        gpg --detach-sign --use-agent -u "$GPG_KEY" \
            --no-armor -o "$pkg.sig" "$pkg"
        SIGNED_COUNT=$((SIGNED_COUNT + 1))
    fi
done

log_info "Signed $SIGNED_COUNT packages"

# ==============================================================================
# Export public key
# ==============================================================================
log_step "Exporting public key"

PUBKEY_FILE="$REPO_DIR/orionos-key.pub"
gpg --export --armor "$GPG_KEY" > "$PUBKEY_FILE" 2>/dev/null || true

if [[ -f "$PUBKEY_FILE" ]]; then
    log_info "Public key exported: $PUBKEY_FILE"
    log_info "Fingerprint: $(gpg --fingerprint "$GPG_KEY" 2>/dev/null | grep -oP '[A-F0-9]{4}(\s+[A-F0-9]{4}){9}' | head -1 || echo 'unknown')"
fi

# ==============================================================================
# Summary
# ==============================================================================
log_section "Repository Signing Complete"

log_info "Repository: $REPO_NAME"
log_info "Location: $REPO_PATH"
log_info "Signed packages: $SIGNED_COUNT"

echo ""
log_info "To verify packages:"
echo "  gpg --verify <package>.pkg.tar.zst.sig <package>.pkg.tar.zst"
