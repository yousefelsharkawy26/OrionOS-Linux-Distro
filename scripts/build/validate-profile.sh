#!/bin/bash
# OrionOS ISO Profile Validator
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PROFILE="${PROJECT_ROOT}/build/profiles/orionos"

PASS=0
FAIL=0

check() {
    if [ -e "$2" ]; then
        echo "  [OK] $1"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL] $1 -- $2"
        FAIL=$((FAIL + 1))
    fi
}

echo ""
echo "OrionOS ISO Profile Validator"
echo "=============================="
echo "Profile: ${PROFILE}"
echo ""

echo "--- Core Profile Files ---"
check "profiledef.sh" "${PROFILE}/profiledef.sh"
check "packages.x86_64" "${PROFILE}/packages.x86_64"
check "pacman.conf" "${PROFILE}/pacman.conf"

echo ""
echo "--- Bootloader Configs ---"
check "GRUB config" "${PROFILE}/grub/grub.cfg"
check "Syslinux config" "${PROFILE}/syslinux/syslinux-linux.cfg"

echo ""
echo "--- System Config ---"
check "hostname" "${PROFILE}/airootfs/etc/hostname"
check "hosts" "${PROFILE}/airootfs/etc/hosts"
check "locale.gen" "${PROFILE}/airootfs/etc/locale.gen"
check "locale.conf" "${PROFILE}/airootfs/etc/locale.conf"
check "os-release" "${PROFILE}/airootfs/etc/os-release"
check "systemd preset" "${PROFILE}/airootfs/etc/systemd/system-preset/99-orionos-live.preset"

echo ""
echo "--- Desktop Config ---"
check "Hyprland config" "${PROFILE}/airootfs/etc/skel/.config/hyprland/hyprland.conf"
check "Hyprpaper config" "${PROFILE}/airootfs/etc/skel/.config/hyprland/hyprpaper.conf"
check "Waybar config" "${PROFILE}/airootfs/etc/skel/.config/waybar/config.jsonc"
check "Waybar style" "${PROFILE}/airootfs/etc/skel/.config/waybar/style.css"
check "Kitty config" "${PROFILE}/airootfs/etc/skel/.config/kitty/kitty.conf"

echo ""
echo "--- Scripts ---"
check "customize_airootfs.sh" "${PROFILE}/airootfs/root/customize_airootfs.sh"
check "orionos-installer" "${PROFILE}/airootfs/usr/bin/orionos-installer"

echo ""
echo "--- Package List ---"
if [ -f "${PROFILE}/packages.x86_64" ]; then
    pkg_count=$(grep -v '^#' "${PROFILE}/packages.x86_64" | grep -v '^$' | wc -l)
    echo "  [OK] Package count: ${pkg_count}"
    PASS=$((PASS + 1))
    for pkg in base linux grub hyprland pipewire networkmanager; do
        if grep -q "^${pkg}$" "${PROFILE}/packages.x86_64"; then
            echo "  [OK] Required package: ${pkg}"
            PASS=$((PASS + 1))
        else
            echo "  [WARN] Missing required package: ${pkg}"
            FAIL=$((FAIL + 1))
        fi
    done
fi

echo ""
echo "--- Build System ---"
check "Dockerfile" "${PROJECT_ROOT}/Dockerfile"
check "build-iso.sh" "${PROJECT_ROOT}/scripts/build/build-iso.sh"
check "build-iso-docker.sh" "${PROJECT_ROOT}/scripts/build/build-iso-docker.sh"
check "build-iso-host.sh" "${PROJECT_ROOT}/scripts/build/build-iso-host.sh"
check "Makefile" "${PROJECT_ROOT}/Makefile"

echo ""
echo "=============================="
echo "Results: ${PASS} passed, ${FAIL} failed"
echo ""
if [ $FAIL -eq 0 ]; then
    echo "Profile is ready for ISO build!"
    echo ""
    echo "Build the ISO:"
    echo "  Arch Linux:   make iso"
    echo "  Docker:       make docker-iso"
else
    echo "Fix issues above before building."
fi
exit $FAIL
