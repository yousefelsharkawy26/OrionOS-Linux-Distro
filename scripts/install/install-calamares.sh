#!/bin/bash
# ==============================================================================
# OrionOS Calamares Installer Setup
# Generates Calamares configuration for OrionOS
# ==============================================================================

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Simple logging
log() {
    echo -e "$1"
}

log_header() {
    log "\n[36m[1m  ============================================"
    log "  $1"
    log "  ============================================[0m"
}

log_step() {
    log "[33m[1m  [*] $1[0m"
}

log_success() {
    log "[32m  [OK] $1[0m"
}

log_header "OrionOS Calamares Installer Configuration"

# ==============================================================================
# Create Calamares configuration directory
# ==============================================================================
log_step "Creating Calamares configuration"

CONFIG_DIR="${PROJECT_ROOT}/build/calamares-config"
mkdir -p "${CONFIG_DIR}"
mkdir -p "${CONFIG_DIR}/modules"

# ==============================================================================
# Create branding
# ==============================================================================
log_step "Creating OrionOS branding"

BRANDING_DIR="${CONFIG_DIR}/branding/orionos"
mkdir -p "${BRANDING_DIR}"

cat > "${BRANDING_DIR}/branding.desc" << 'BRANDING_EOF'
# OrionOS Calamares Branding
# Custom branding for OrionOS installer

componentName: orionos
welcomeStyleCalamares: true
welcomeExpandingLogo: false
welcomeLogo: welcome.png
welcomeWelcomeImage: welcome.png

# Branding strings
strings:
  productName: "OrionOS"
  shortProductName: "OrionOS"
  version: "0.2.0-beta"
  shortVersion: "0.2.0"
  versionedName: "OrionOS 0.2.0 Beta"
  shortVersionedName: "OrionOS 0.2.0"
  bootloaderEntryName: "OrionOS"
  productUrl: "https://orionos.org"
  supportUrl: "https://forum.orionos.org"
  bugReportUrl: "https://github.com/yousefelsharkawy26/OrionOS-Linux-Distro/issues"
  releaseNotesUrl: "https://github.com/yousefelsharkawy26/OrionOS-Linux-Distro/releases"

# Slide show
showSlideShow: true
slideShow: "show.qml"
slideShowAPI: 2

# Style
style:
  sidebarBackground: "#1e2030"
  sidebarText: "#cad3f5"
  sidebarTextSelect: "#8aadf4"
  sidebarTextHighlight: "#8aadf4"
  sidebarBackgroundCurrent: "#24273a"
  
  logo: "logo.png"
  
  # Button styles
  buttonText: "#cad3f5"
  buttonTextSelect: "#1e2030"
  buttonBackground: "#363a4f"
  buttonBackgroundSelect: "#8aadf4"
  
  # Progress bar
  progressBarBackground: "#363a4f"
  progressBarForeground: "#8aadf4"
  
  # Text input
  textInputBackground: "#24273a"
  textInputText: "#cad3f5"
  textInputTextSelect: "#1e2030"
  
  # Checkbox/radio
  checkboxBackground: "#363a4f"
  checkboxCheckmark: "#8aadf4"
  
  # Scrollbar
  scrollBarBackground: "#1e2030"
  scrollBarHandle: "#6e738d"
  scrollBarHandleHover: "#8aadf4"

# Images
images:
  productLogo: "logo.png"
  productWelcome: "welcome.png"
  productIcon: "logo.svg"
BRANDING_EOF

# ==============================================================================
# Create settings.conf
# ==============================================================================
log_step "Creating main settings"

cat > "${CONFIG_DIR}/settings.conf" << 'SETTINGS_EOF'
# OrionOS Calamares Settings
# Main configuration file for OrionOS installer

# General settings
sequence:
  - show:
    - welcome
    - locale
    - keyboard
    - partition
    - users
    - summary
  - exec:
    - orionos-install
  - show:
    - finished

# Branding
branding: orionos

# Interface settings
prompt-install: false
dont-chroot: false
oem-setup: false

# Debug settings
debug: false
testing: false

# Modules directory
modules-search:
  - /usr/share/calamares/modules
  - ${CONFIG_DIR}/modules
SETTINGS_EOF

# ==============================================================================
# Create modules
# ==============================================================================
log_step "Creating OrionOS modules"

# OrionOS main module
cat > "${CONFIG_DIR}/modules/orionos.conf" << 'ORIONOS_EOF'
# OrionOS Calamares Module Configuration
# Custom modules for OrionOS installation

- name: orionos
  weight: 10
  required: true
  
  # OrionOS-specific installation steps
  steps:
    - name: orionos-welcome
      module: welcome
      config: ${CONFIG_DIR}/modules/welcome.conf
      
    - name: orionos-location
      module: locale
      config: ${CONFIG_DIR}/modules/locale.conf
      
    - name: orionos-keyboard
      module: keyboard
      config: ${CONFIG_DIR}/modules/keyboard.conf
      
    - name: orionos-partition
      module: partition
      config: ${CONFIG_DIR}/modules/partition-orionos.conf
      
    - name: orionos-users
      module: users
      config: ${CONFIG_DIR}/modules/users.conf
      
    - name: orionos-summary
      module: summary
      config: ${CONFIG_DIR}/modules/summary.conf
      
    - name: orionos-install
      module: orionos-install
      config: ${CONFIG_DIR}/modules/orionos-install.conf
      
    - name: orionos-postinstall
      module: orionos-postinstall
      config: ${CONFIG_DIR}/modules/orionos-postinstall.conf
      
    - name: orionos-finished
      module: finished
      config: ${CONFIG_DIR}/modules/finished.conf
ORIONOS_EOF

# Partition module for OrionOS
cat > "${CONFIG_DIR}/modules/partition-orionos.conf" << 'PARTITION_EOF'
# OrionOS Partition Module Configuration
# Custom partitioning for OrionOS with Btrfs

- name: partition
  type: partition
  
  # Partitioning scheme
  scheme:
    - name: efi
      filesystem: fat32
      size: 512
      mountPoint: /boot/efi
      flags: [boot, esp]
      
    - name: swap
      filesystem: linuxswap
      size: 8192  # 8GB
      
    - name: root
      filesystem: btrfs
      size: 0     # Use remaining space
      mountPoint: /
      btrfs:
        subvolumes:
          - name: @
            mountPoint: /
          - name: @home
            mountPoint: /home
          - name: @var
            mountPoint: /var
          - name: @tmp
            mountPoint: /tmp
          - name: @snapshots
            mountPoint: /.snapshots
  
  # Default filesystem
  defaultFileSystemType: btrfs
  
  # Btrfs options
  btrfsOptions:
    - compress=zstd:3
    - noatime
    - space_cache=v2
    - ssd
  
  # Encryption
  enableLuks: true
  luksKeyFile: /crypto_keyfile.bin
  
  # Bootloader
  bootloader: grub
  efiBootloaderId: OrionOS
  
  # Partition flags
  drawNestedPartitions: true
  alwaysShowPartitionLabels: true
PARTITION_EOF

# Post-install module
cat > "${CONFIG_DIR}/modules/orionos-postinstall.conf" << 'POSTINSTALL_EOF'
# OrionOS Post-Installation Configuration
# Custom post-installation steps for OrionOS

- name: orionos-postinstall
  type: job
  
  # OrionOS-specific post-installation tasks
  jobs:
    - name: configure-btrfs
      command: ${CONFIG_DIR}/orionos-configure-btrfs
      
    - name: setup-snapshots
      command: ${CONFIG_DIR}/orionos-setup-snapshots
      
    - name: install-orionos-packages
      command: pacman -S --noconfirm orionos-config orionos-desktop orionos-security orionos-services orionos-themes orionos-utils
      
    - name: enable-orionos-services
      command: systemctl enable orionos-perfd orionos-updated orionos-powerd
      
    - name: configure-grub
      command: grub-mkconfig -o /boot/grub/grub.cfg
      
    - name: create-initial-snapshot
      command: btrfs subvolume snapshot -r / /.snapshots/initial-install
POSTINSTALL_EOF

# ==============================================================================
# Create helper scripts
# ==============================================================================
log_step "Creating helper scripts"

# Create orionos-configure-btrfs script
cat > "${CONFIG_DIR}/orionos-configure-btrfs" << 'CONFIG_BTRFS_EOF'
#!/usr/bin/env python3
"""
OrionOS Btrfs Configuration
Configures Btrfs subvolumes and mount options
"""

import os
import subprocess
from pathlib import Path

def configure_btrfs():
    """Configure Btrfs subvolumes and mount options"""
    root_mount = "/tmp/calamares-root"
    
    # Mount options
    btrfs_opts = "noatime,compress=zstd:3,space_cache=v2,ssd"
    
    # Create subvolumes
    subvolumes = [
        ("@", "/"),
        ("@home", "/home"),
        ("@var", "/var"),
        ("@tmp", "/tmp"),
        ("@snapshots", "/.snapshots")
    ]
    
    # Mount root subvolume
    subprocess.run([
        "mount", "-o", f"{btrfs_opts},subvol=@", 
        "/dev/mapper/orionos-root", root_mount
    ], check=True)
    
    # Create and mount other subvolumes
    for subvol, mount_point in subvolumes[1:]:
        full_path = os.path.join(root_mount, mount_point.lstrip("/"))
        os.makedirs(full_path, exist_ok=True)
        subprocess.run([
            "mount", "-o", f"{btrfs_opts},subvol={subvol}", 
            "/dev/mapper/orionos-root", full_path
        ], check=True)

if __name__ == "__main__":
    configure_btrfs()
CONFIG_BTRFS_EOF

chmod +x "${CONFIG_DIR}/orionos-configure-btrfs"

# Create orionos-setup-snapshots script
cat > "${CONFIG_DIR}/orionos-setup-snapshots" << 'SETUP_SNAPSHOTS_EOF'
#!/usr/bin/env python3
"""
OrionOS Snapshot Setup
Creates initial Btrfs snapshots
"""

import subprocess
from pathlib import Path

def setup_snapshots():
    """Create initial Btrfs snapshots"""
    root_mount = "/tmp/calamares-root"
    
    # Create initial snapshot
    subprocess.run([
        "btrfs", "subvolume", "snapshot", "-r", 
        f"{root_mount}", f"{root_mount}/.snapshots/initial-install"
    ], check=True)

if __name__ == "__main__":
    setup_snapshots()
SETUP_SNAPSHOTS_EOF

chmod +x "${CONFIG_DIR}/orionos-setup-snapshots"

# ==============================================================================
# Create launcher script
# ==============================================================================
log_step "Creating launcher script"

cat > "${CONFIG_DIR}/orionos-installer" << 'LAUNCHER_EOF'
#!/bin/bash
# OrionOS Installer Launcher
# Starts Calamares with OrionOS configuration

# Check if Calamares is installed
if ! command -v calamares &>/dev/null; then
    echo "Error: Calamares is not installed."
    echo "Please install Calamares first:"
    echo "  sudo pacman -S calamares"
    exit 1
fi

# Start Calamares with OrionOS configuration
calamares -d -c "${CONFIG_DIR}/settings.conf"
LAUNCHER_EOF

chmod +x "${CONFIG_DIR}/orionos-installer"

# ==============================================================================
# Summary
# ==============================================================================
log_success "Calamares configuration generated!"
log "Configuration files created in: ${CONFIG_DIR}"
log "To use this configuration:"
log "1. Install Calamares: sudo pacman -S calamares"
log "2. Run the installer: sudo ${CONFIG_DIR}/orionos-installer"
log "3. Place branding files (logo.png, welcome.png) in: ${BRANDING_DIR}"
