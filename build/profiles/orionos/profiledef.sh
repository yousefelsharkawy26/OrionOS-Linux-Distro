#!/usr/bin/env bash
# OrionOS ISO profile

build_date="$(date +%Y.%m.%d)"
iso_name="orionos"
iso_label="ORIONOS_$(date +%Y%m)"
iso_publisher="OrionOS <https://orionos.org>"
iso_application="OrionOS Live/Install Environment"
iso_version="$(cat "${PROJECT_ROOT:-.}/VERSION" 2>/dev/null || echo 1.0.0)"
install_dir="arch"
bootmodes=(
  'bios.syslinux.mbr'
  'bios.syslinux.eltorito'
  'uefi-ia32.grub.eltorito'
  'uefi-x64.grub.eltorito'
)
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '19' '-b' '1M')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/gshadow"]="0:0:400"
  ["/usr/bin/orionos-cli"]="0:0:755"
  ["/usr/bin/orionos-installer"]="0:0:755"
  ["/usr/bin/orionos-setup"]="0:0:755"
  ["/usr/local/bin/orionos-welcome"]="0:0:755"
)
