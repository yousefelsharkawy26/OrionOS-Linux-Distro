#!/bin/bash
# =============================================================================
# OrionOS Package Repository Creation
# Creates a pacman-compatible package database
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PKG_DIR="${1:-${PROJECT_ROOT}/build/packages}"
REPO_DIR="${2:-${PROJECT_ROOT}/build/repo}"
REPO_NAME="orionos"

source "${PROJECT_ROOT}/scripts/build/logging.sh"

log_section "OrionOS Package Repository Creation"
log_info "Source: ${PKG_DIR}"
log_info "Output: ${REPO_DIR}"

mkdir -p "$REPO_DIR"

# Collect all packages
log_info "Collecting packages..."
find "$PKG_DIR" -name "*.pkg.tar.zst" -exec cp -f {} "$REPO_DIR/" \;

# Remove old database
rm -f "${REPO_DIR}/${REPO_NAME}.db" "${REPO_DIR}/${REPO_NAME}.db.tar.gz"
rm -f "${REPO_DIR}/${REPO_NAME}.files" "${REPO_DIR}/${REPO_NAME}.files.tar.gz"

# Create package database
log_info "Creating package database..."
cd "$REPO_DIR"

# Add each package to the database
for pkg in *.pkg.tar.zst; do
    if [[ -f "$pkg" ]]; then
        log_info "Adding ${pkg} to database..."
        repo-add "${REPO_NAME}.db.tar.gz" "$pkg"
    fi
done

# Symlink database files
ln -sf "${REPO_NAME}.db.tar.gz" "${REPO_NAME}.db" 2>/dev/null || true
ln -sf "${REPO_NAME}.files.tar.gz" "${REPO_NAME}.files" 2>/dev/null || true

# Generate repository info
log_info "Generating repository metadata..."
PACMAN_DB_VERSION="$(date +%s)"
PKG_COUNT="$(ls -1 *.pkg.tar.zst 2>/dev/null | wc -l)"

cat > "${REPO_DIR}/repo-info.json" << EOF
{
    "name": "${REPO_NAME}",
    "version": "$(cat ${PROJECT_ROOT}/VERSION)",
    "db_version": ${PACMAN_DB_VERSION},
    "package_count": ${PKG_COUNT},
    "architecture": "x86_64",
    "last_updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "packages": [
$(for p in *.pkg.tar.zst; do
    if [[ -f "$p" ]]; then
        echo "        \"$p\""
    fi
done | paste -sd, -)
    ]
}
EOF

# Generate HTML index for web access
log_info "Generating web index..."
cat > "${REPO_DIR}/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OrionOS Package Repository</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #0f0f23 0%, #1a1a3e 50%, #16213e 100%);
            color: #e0e0e0;
            min-height: 100vh;
            padding: 40px;
        }
        .container { max-width: 1200px; margin: 0 auto; }
        header { text-align: center; margin-bottom: 60px; }
        h1 {
            font-size: 3em;
            background: linear-gradient(135deg, #00d4ff, #7b2ff7);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            margin-bottom: 10px;
        }
        .subtitle { color: #888; font-size: 1.2em; }
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 40px;
        }
        .stat-card {
            background: rgba(255,255,255,0.05);
            border-radius: 16px;
            padding: 24px;
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255,255,255,0.1);
        }
        .stat-value {
            font-size: 2.5em;
            font-weight: bold;
            color: #00d4ff;
        }
        .stat-label { color: #888; font-size: 0.9em; margin-top: 8px; }
        .packages { margin-top: 40px; }
        .package-list {
            background: rgba(255,255,255,0.03);
            border-radius: 16px;
            padding: 20px;
            border: 1px solid rgba(255,255,255,0.08);
        }
        .package-item {
            padding: 12px 16px;
            border-bottom: 1px solid rgba(255,255,255,0.05);
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .package-item:last-child { border-bottom: none; }
        .package-name { font-family: monospace; color: #00d4ff; }
        .package-size { color: #888; font-size: 0.9em; }
        .footer {
            text-align: center;
            margin-top: 60px;
            color: #666;
            font-size: 0.9em;
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>OrionOS</h1>
            <p class="subtitle">Package Repository</p>
        </header>
        <div class="stats">
            <div class="stat-card">
                <div class="stat-value" id="pkg-count">-</div>
                <div class="stat-label">Packages</div>
            </div>
            <div class="stat-card">
                <div class="stat-value" id="repo-version">-</div>
                <div class="stat-label">Version</div>
            </div>
            <div class="stat-card">
                <div class="stat-value" id="last-updated">-</div>
                <div class="stat-label">Last Updated</div>
            </div>
        </div>
        <div class="packages">
            <h2 style="margin-bottom: 20px; color: #e0e0e0;">Available Packages</h2>
            <div class="package-list" id="package-list"></div>
        </div>
        <div class="footer">
            <p>OrionOS Linux Distribution &copy; 2024</p>
            <p>Add this repository: <code style="background: rgba(255,255,255,0.1); padding: 4px 8px; border-radius: 4px;">Server = https://repo.orionos.org/$repo/os/$arch</code></p>
        </div>
    </div>
    <script>
        fetch('repo-info.json')
            .then(r => r.json())
            .then(data => {
                document.getElementById('pkg-count').textContent = data.package_count;
                document.getElementById('repo-version').textContent = data.version;
                document.getElementById('last-updated').textContent = new Date(data.last_updated).toLocaleDateString();
                const list = document.getElementById('package-list');
                data.packages.forEach(pkg => {
                    const div = document.createElement('div');
                    div.className = 'package-item';
                    div.innerHTML = `<span class="package-name">${pkg}</span>`;
                    list.appendChild(div);
                });
            })
            .catch(e => console.error('Failed to load package info:', e));
    </script>
</body>
</html>
EOF

log_success "Repository created successfully!"
log_info "Location: ${REPO_DIR}"
log_info "Packages: ${PKG_COUNT}"
log_info "Database: ${REPO_DIR}/${REPO_NAME}.db.tar.gz"
