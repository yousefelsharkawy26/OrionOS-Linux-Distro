#!/bin/bash
# =============================================================================
# OrionOS Package Repository Signing
# Signs the package database with GPG for secure distribution
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
REPO_DIR="${1:-${PROJECT_ROOT}/build/repo}"
REPO_NAME="orionos"
GPG_KEY="${ORIONOS_GPG_KEY:-team@orionos.org}"

source "${PROJECT_ROOT}/scripts/build/logging.sh"

log_section "OrionOS Package Repository Signing"
log_info "Repository: ${REPO_DIR}"
log_info "Key: ${GPG_KEY}"

cd "$REPO_DIR"

# Check for GPG key
if ! gpg --list-keys "$GPG_KEY" &>/dev/null; then
    log_warn "GPG key not found: $GPG_KEY"
    log_info "Generating new signing key..."

    # Generate a temporary signing key for CI
    export GNUPGHOME=$(mktemp -d)
    cat > "$GNUPGHOME/gen-key-script" <<EOF
%no-protection
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: OrionOS Build System
Name-Email: ${GPG_KEY}
Expire-Date: 0
%commit
EOF
    gpg --batch --gen-key "$GNUPGHOME/gen-key-script" 2>/dev/null
fi

# Sign the database
log_info "Signing package database..."
if [[ -f "${REPO_NAME}.db.tar.gz" ]]; then
    # Sign the database
    gpg --detach-sign --use-agent -u "$GPG_KEY" "${REPO_NAME}.db.tar.gz"

    # Also sign the files database
    if [[ -f "${REPO_NAME}.files.tar.gz" ]]; then
        gpg --detach-sign --use-agent -u "$GPG_KEY" "${REPO_NAME}.files.tar.gz"
    fi

    # Export public key for distribution
    gpg --export --armor "$GPG_KEY" > "${REPO_NAME}.key"

    log_success "Repository signed successfully!"
    log_info "Public key: ${REPO_DIR}/${REPO_NAME}.key"
else
    log_error "Package database not found: ${REPO_NAME}.db.tar.gz"
    exit 1
fi

# Verify signature
log_info "Verifying signature..."
if gpg --verify "${REPO_NAME}.db.tar.gz.sig" "${REPO_NAME}.db.tar.gz" 2>/dev/null; then
    log_success "Signature verified!"
else
    log_error "Signature verification failed!"
    exit 1
fi
