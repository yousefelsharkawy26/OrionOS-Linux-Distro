#!/bin/bash
# ==============================================================================
# OrionOS Installer
# Graphical/CLI installer for OrionOS
# Supports both Calamares integration and CLI fallback
# ==============================================================================

set -euo pipefail

# Version
VERSION="0.1.0-alpha"
CODENAME="Nebula"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Logging
LOG_FILE="/tmp/orionos-install.log"
exec 1> >(tee -a "$LOG_FILE")
exec 2> >(tee -a "$LOG_FILE" >&2)

# ==============================================================================
# Utility Functions
# ==============================================================================

print_header() {
    clear
    echo ""
    echo -e "${BLUE}${BOLD}  ╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}${BOLD}  ║                                                               ║${NC}"
    echo -e "${BLUE}${BOLD}  ║${NC}              ${CYAN}${BOLD}OrionOS ${VERSION}${NC} - ${CYAN}${BOLD}${CODENAME}${NC}                  ${BLUE}${BOLD}║${NC}"
    echo -e "${BLUE}${BOLD}  ║${NC}         ${CYAN}The Future of Desktop Linux${NC}                         ${BLUE}${BOLD}║${NC}"
    echo -e "${BLUE}${BOLD}  ║                                                               ║${NC}"
    echo -e "${BLUE}${BOLD}  ╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo -e "${CYAN}${BOLD}  → $1${NC}"
}

print_success() {
    echo -e "${GREEN}${BOLD}  ✓ $1${NC}"
}

print_error() {
    echo -e "${RED}${BOLD}  ✗ $1${NC}" >&2
}

print_warn() {
    echo -e "${YELLOW}${BOLD}  ⚠ $1${NC}"
}

print_info() {
    echo -e "  $1"
}

confirm() {
    echo ""
    read -p "  $1 [Y/n]: " -n 1 -r
    echo ""
    [[ -z "$REPLY" || "$REPLY" =~ ^[Yy]$ ]]
}

select_option() {
    local prompt="$1"
    shift
    local options=("$@")
    local selected=0

    while true; do
        echo ""
        echo -e "  ${CYAN}${prompt}${NC}"
        for i in "${!options[@]}"; do
            if [[ $i -eq $selected ]]; then
                echo -e "  ${GREEN}${BOLD}  ▶ ${options[$i]}${NC}"
            else
                echo -e "      ${options[$i]}"
            fi
        done

        read -rs -n 1 key
        case "$key" in
            $'\x1b')
                read -rs -n 2 key
                case "$key" in
                    '[A') # Up
                        selected=$(( (selected - 1 + ${#options[@]}) % ${#options[@]} ))
                        ;;
                    '[B') # Down
                        selected=$(( (selected + 1) % ${#options[@]} ))
                        ;;
                esac
                # Redraw
                for i in "${!options[@]}"; do
                    echo -ne "\033[1A\033[2K\r"
                done
                echo -ne "\033[1A\033[2K\r"
                ;;
            '') # Enter
                echo ""
                return $selected
                ;;
        esac
    done
}

# ==============================================================================
# System Checks
# ==============================================================================

check_uefi() {
    [[ -d /sys/firmware/efi/efivars ]]
}

check_internet() {
    curl -s --max-time 5 https://archlinux.org/ > /dev/null 2>&1
}

check_disk_space() {
    local available
    available=$(df / | awk 'NR==2 {print $4}')
    # Need at least 20GB free (20971520 blocks of 1K)
    [[ $available -gt 20971520 ]]
}

# ==============================================================================
# Disk Management
# ==============================================================================

list_disks() {
    lsblk -dpno NAME,SIZE,TYPE,MODEL | grep -E "disk|loop" | awk '{print $1, $2, $4}'
}

get_disk_size() {
    local disk="$1"
    lsblk -dnbo SIZE "$disk" 2>/dev/null | awk '{print int($1/1024/1024/1024)}'
}

# ==============================================================================
# Partitioning
# ==============================================================================

auto_partition_btrfs() {
    local disk="$1"
    local swap_size="${2:-8}"

    print_step "Creating partitions on $disk"

    # Wipe disk
    wipefs -af "$disk" &>/dev/null || true
    sgdisk -Zo "$disk" &>/dev/null || true

    if check_uefi; then
        # UEFI: EFI + Swap + Root
        print_info "Partition scheme: UEFI + Btrfs"
        
        # EFI partition (512MB)
        parted -s "$disk" mklabel gpt
        parted -s "$disk" mkpart primary fat32 1MiB 513MiB
        parted -s "$disk" set 1 esp on
        
        # Swap partition
        parted -s "$disk" mkpart primary linux-swap 513MiB "$((513 + swap_size * 1024))MiB"
        
        # Root partition (Btrfs)
        parted -s "$disk" mkpart primary btrfs "$((513 + swap_size * 1024))MiB" 100%
    else
        # BIOS: Boot + Swap + Root
        print_info "Partition scheme: BIOS + Btrfs"
        
        # Boot partition (1GB)
        parted -s "$disk" mklabel msdos
        parted -s "$disk" mkpart primary ext4 1MiB 1025MiB
        parted -s "$disk" set 1 boot on
        
        # Swap partition
        parted -s "$disk" mkpart primary linux-swap 1025MiB "$((1025 + swap_size * 1024))MiB"
        
        # Root partition (Btrfs)
        parted -s "$disk" mkpart primary btrfs "$((1025 + swap_size * 1024))MiB" 100%
    fi

    # Wait for kernel to recognize partitions
    partprobe "$disk"
    sleep 2

    print_success "Partitions created"
}

# ==============================================================================
# Filesystem Setup
# ==============================================================================

setup_btrfs() {
    local root_part="$1"
    local efi_part="${2:-}"
    local swap_part="${3:-}"
    local hostname="${4:-orionos}"
    local username="${5:-user}"
    local timezone="${6:-UTC}"
    local locale="${7:-en_US.UTF-8}"

    print_step "Setting up Btrfs filesystem"

    # Format root as Btrfs
    print_info "Formatting root partition ($root_part) as Btrfs"
    mkfs.btrfs -f -L "orionos_root" "$root_part"

    # Create subvolumes
    print_info "Creating Btrfs subvolumes"
    mount "$root_part" /mnt

    # Create subvolumes
    btrfs subvolume create /mnt/@
    btrfs subvolume create /mnt/@home
    btrfs subvolume create /mnt/@var
    btrfs subvolume create /mnt/@tmp
    btrfs subvolume create /mnt/@snapshots

    umount /mnt

    # Mount subvolumes with optimized options
    local btrfs_opts="noatime,compress=zstd:3,space_cache=v2,ssd"
    mount -o "${btrfs_opts},subvol=@" "$root_part" /mnt

    # Create mount points
    mkdir -p /mnt/{home,var,tmp,boot,efi,.snapshots}

    mount -o "${btrfs_opts},subvol=@home" "$root_part" /mnt/home
    mount -o "${btrfs_opts},subvol=@var" "$root_part" /mnt/var
    mount -o "${btrfs_opts},subvol=@tmp" "$root_part" /mnt/tmp
    mount -o "${btrfs_opts},subvol=@snapshots" "$root_part" /mnt/.snapshots

    # Format and mount EFI
    if [[ -n "$efi_part" ]]; then
        print_info "Formatting EFI partition ($efi_part) as FAT32"
        mkfs.fat -F 32 -n "EFI" "$efi_part"
        mount "$efi_part" /mnt/efi
    fi

    # Setup swap
    if [[ -n "$swap_part" ]]; then
        print_info "Setting up swap partition ($swap_part)"
        mkswap -L "swap" "$swap_part"
        swapon "$swap_part"
    fi

    print_success "Btrfs filesystem configured"
}

# ==============================================================================
# Base System Installation
# ==============================================================================

install_base_system() {
    print_step "Installing base system"

    # Install essential packages
    print_info "This may take 15-30 minutes depending on your internet connection..."
    
    cat > /mnt/etc/pacman.d/mirrorlist << 'EOF'
## OrionOS Mirror List
## Generated during installation
Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch
Server = https://mirror.rackspace.com/archlinux/$repo/os/$arch
Server = https://mirrors.kernel.org/archlinux/$repo/os/$arch
EOF

    # Install base system
    pacstrap -K /mnt base base-devel linux linux-headers linux-firmware \
        btrfs-progs grub grub-btrfs efibootmgr os-prober dosfstools \
        networkmanager iwd openssh curl wget \
        git vim nano bash bash-completion zsh \
        man-db man-pages texinfo \
        pacman-contrib reflector \
        pipewire pipewire-pulse pipewire-jack pipewire-alsa wireplumber \
        mesa vulkan-intel vulkan-radeon \
        bluez bluez-utils \
        noto-fonts noto-fonts-emoji \
        thermald irqbalance

    # Generate fstab
    print_info "Generating fstab"
    genfstab -U /mnt >> /mnt/etc/fstab

    print_success "Base system installed"
}

# ==============================================================================
# System Configuration
# ==============================================================================

configure_system() {
    local hostname="$1"
    local username="$2"
    local timezone="$3"
    local locale="$4"
    local password="$5"

    print_step "Configuring system"

    # Set timezone
    print_info "Setting timezone to $timezone"
    ln -sf "/usr/share/zoneinfo/$timezone" /mnt/etc/localtime
    arch-chroot /mnt hwclock --systohc

    # Set locale
    print_info "Setting locale to $locale"
    echo "$locale UTF-8" > /mnt/etc/locale.gen
    arch-chroot /mnt locale-gen
    echo "LANG=$locale" > /mnt/etc/locale.conf

    # Set hostname
    print_info "Setting hostname to $hostname"
    echo "$hostname" > /mnt/etc/hostname
    cat > /mnt/etc/hosts << EOF
127.0.0.1   localhost
127.0.1.1   $hostname
::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
EOF

    # Create user
    print_info "Creating user: $username"
    arch-chroot /mnt useradd -m -G wheel,audio,video,network,storage,power -s /bin/bash "$username"
    echo "$username:$password" | arch-chroot /mnt chpasswd
    echo "root:$password" | arch-chroot /mnt chpasswd

    # Configure sudo
    echo "%wheel ALL=(ALL:ALL) ALL" > /mnt/etc/sudoers.d/wheel
    chmod 440 /mnt/etc/sudoers.d/wheel

    # Enable services
    print_info "Enabling system services"
    arch-chroot /mnt systemctl enable NetworkManager
    arch-chroot /mnt systemctl enable bluetooth
    arch-chroot /mnt systemctl enable sshd
    arch-chroot /mnt systemctl enable thermald
    arch-chroot /mnt systemctl enable irqbalance

    # Configure mkinitcpio for Btrfs
    print_info "Configuring initramfs"
    sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect keyboard keymap modconf block filesystems btrfs fsck)/' \
        /mnt/etc/mkinitcpio.conf
    arch-chroot /mnt mkinitcpio -P

    # Install and configure GRUB
    print_info "Installing bootloader"
    if [[ -d /sys/firmware/efi/efivars ]]; then
        # UEFI
        arch-chroot /mnt grub-install --target=x86_64-efi \
            --efi-directory=/efi \
            --bootloader-id=OrionOS \
            --removable
    else
        # BIOS
        local disk
        disk=$(lsblk -dpno PKNAME "$(findmnt -nvo SOURCE /mnt)")
        arch-chroot /mnt grub-install --target=i386-p "$disk"
    fi

    # Configure GRUB
    sed -i 's/^GRUB_DEFAULT=.*/GRUB_DEFAULT=saved/' /mnt/etc/default/grub
    sed -i 's/^GRUB_SAVEDEFAULT=.*/GRUB_SAVEDEFAULT=true/' /mnt/etc/default/grub
    sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash loglevel=3 mitigations=auto"/' /mnt/etc/default/grub
    sed -i 's/^#GRUB_BTRFS_OVERRIDE_BOOT_PARTITION_DETECTION=.*/GRUB_BTRFS_OVERRIDE_BOOT_PARTITION_DETECTION=true/' /mnt/etc/default/grub
    sed -i 's/^GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' /mnt/etc/default/grub

    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

    print_success "System configured"
}

# ==============================================================================
# OrionOS-specific Setup
# ==============================================================================

install_orionos_packages() {
    print_step "Installing OrionOS packages"

    # Create local repository for OrionOS packages
    if ls /var/cache/pacman/orionos/*.pkg.tar.* &>/dev/null; then
        print_info "Installing OrionOS packages from local repository"
        mkdir -p /mnt/var/cache/pacman/orionos
        cp /var/cache/pacman/orionos/*.pkg.tar.* /mnt/var/cache/pacman/orionos/
        
        cat >> /mnt/etc/pacman.conf << 'EOF'

[orionos-local]
SigLevel = Optional TrustAll
Server = file:///var/cache/pacman/orionos
EOF
        
        cd /mnt/var/cache/pacman/orionos
        repo-add orionos-local.db.tar.gz *.pkg.tar.*
        cd /
        
        arch-chroot /mnt pacman -Sy --noconfirm \
            orionos-config orionos-desktop orionos-security \
            orionos-services orionos-themes orionos-utils
    else
        print_warn "OrionOS packages not found in local cache"
        print_info "You can install them after first boot with:"
        print_info "  sudo pacman -S orionos-config orionos-desktop orionos-security orionos-services orionos-themes orionos-utils"
    fi

    print_success "OrionOS packages installed"
}

# ==============================================================================
# Main Installation Flow
# ==============================================================================

run_installation() {
    local disk="$1"
    local hostname="$2"
    local username="$3"
    local password="$4"
    local timezone="$5"
    local locale="$6"
    local swap_size="${7:-8}"

    # Identify partitions
    local efi_part=""
    local swap_part=""
    local root_part=""

    if check_uefi; then
        efi_part="${disk}1"
        swap_part="${disk}2"
        root_part="${disk}3"
    else
        swap_part="${disk}2"
        root_part="${disk}3"
    fi

    # Run installation steps
    auto_partition_btrfs "$disk" "$swap_size"
    setup_btrfs "$root_part" "$efi_part" "$swap_part" "$hostname" "$username" "$timezone" "$locale"
    install_base_system
    configure_system "$hostname" "$username" "$timezone" "$locale" "$password"
    install_orionos_packages

    # Final steps
    print_step "Finalizing installation"
    
    # Create initial snapshot
    if command -v btrfs &>/dev/null; then
        print_info "Creating initial system snapshot"
        mount -o subvol=@ "$root_part" /mnt
        btrfs subvolume snapshot -r /mnt /mnt/.snapshots/initial-install
        umount /mnt
    fi

    # Unmount all
    umount -R /mnt 2>/dev/null || true
    swapoff -a 2>/dev/null || true

    print_success "Installation complete!"
}

# ==============================================================================
# Interactive CLI
# ==============================================================================

interactive_install() {
    print_header

    # Welcome
    echo -e "  ${BOLD}Welcome to the OrionOS Installer!${NC}"
    echo ""
    echo "  This installer will guide you through setting up OrionOS"
    echo "  on your computer. All data on the selected disk will be erased."
    echo ""
    
    if ! confirm "Continue with installation?"; then
        echo "  Installation cancelled."
        exit 0
    fi

    # Check requirements
    print_step "Checking system requirements"
    
    if ! check_internet; then
        print_error "No internet connection detected"
        print_info "Please connect to the internet and try again"
        exit 1
    fi
    print_success "Internet connection OK"

    if check_uefi; then
        print_success "UEFI mode detected"
    else
        print_warn "BIOS mode detected"
    fi

    # Select disk
    print_step "Select installation disk"
    echo ""
    
    local disks=()
    while IFS= read -r line; do
        disks+=("$line")
    done < <(list_disks)

    if [[ ${#disks[@]} -eq 0 ]]; then
        print_error "No disks found"
        exit 1
    fi

    echo -e "  ${CYAN}Available disks:${NC}"
    for i in "${!disks[@]}"; do
        echo "    [$((i+1))] ${disks[$i]}"
    done
    echo ""
    
    local disk_choice
    read -p "  Select disk [1-${#disks[@]}]: " disk_choice
    
    if ! [[ "$disk_choice" =~ ^[0-9]+$ ]] || [[ $disk_choice -lt 1 || $disk_choice -gt ${#disks[@]} ]]; then
        print_error "Invalid selection"
        exit 1
    fi

    local selected_disk="${disks[$((disk_choice-1))]}"
    local disk_device
    disk_device=$(echo "$selected_disk" | awk '{print $1}')
    local disk_size
    disk_size=$(echo "$selected_disk" | awk '{print $2}')
    
    echo ""
    print_warn "Selected disk: $disk_device ($disk_size)"
    print_warn "ALL DATA ON THIS DISK WILL BE ERASED!"
    
    if ! confirm "Are you sure you want to continue?"; then
        echo "  Installation cancelled."
        exit 0
    fi

    # Hostname
    echo ""
    read -p "  Enter hostname [orionos]: " hostname
    hostname="${hostname:-orionos}"

    # Username
    echo ""
    read -p "  Enter username [user]: " username
    username="${username:-user}"

    # Password
    echo ""
    while true; do
        read -s -p "  Enter password: " password
        echo ""
        read -s -p "  Confirm password: " password2
        echo ""
        if [[ "$password" == "$password2" && -n "$password" ]]; then
            break
        fi
        print_error "Passwords do not match or are empty"
    done

    # Timezone
    echo ""
    read -p "  Enter timezone [UTC]: " timezone
    timezone="${timezone:-UTC}"

    # Locale
    echo ""
    read -p "  Enter locale [en_US.UTF-8]: " locale
    locale="${locale:-en_US.UTF-8}"

    # Swap size
    echo ""
    read -p "  Swap size in GB [8]: " swap_size
    swap_size="${swap_size:-8}"

    # Summary
    print_header
    echo -e "  ${BOLD}Installation Summary:${NC}"
    echo ""
    echo "    Disk:      $disk_device ($disk_size)"
    echo "    Hostname:  $hostname"
    echo "    Username:  $username"
    echo "    Timezone:  $timezone"
    echo "    Locale:    $locale"
    echo "    Swap:      ${swap_size}GB"
    echo "    UEFI:      $(check_uefi && echo "Yes" || echo "No")"
    echo ""

    if ! confirm "Start installation?"; then
        echo "  Installation cancelled."
        exit 0
    fi

    # Run installation
    print_header
    run_installation "$disk_device" "$hostname" "$username" "$password" "$timezone" "$locale" "$swap_size"

    # Done
    print_header
    print_success "OrionOS has been installed successfully!"
    echo ""
    echo -e "  ${BOLD}Next steps:${NC}"
    echo "    1. Remove the installation medium"
    echo "    2. Reboot your system"
    echo "    3. Log in with your username and password"
    echo ""
    echo -e "  ${CYAN}reboot${NC} to restart your computer"
    echo ""
}

# ==============================================================================
# Automated / Unattended Installation
# ==============================================================================

unattended_install() {
    local config_file="$1"

    print_header
    print_step "Running unattended installation"

    if [[ ! -f "$config_file" ]]; then
        print_error "Config file not found: $config_file"
        exit 1
    fi

    # Source config
    source "$config_file"

    # Validate required variables
    local required_vars=("DISK" "HOSTNAME" "USERNAME" "PASSWORD")
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            print_error "Required variable not set: $var"
            exit 1
        fi
    done

    # Run installation
    run_installation "$DISK" "$HOSTNAME" "$USERNAME" "$PASSWORD" \
        "${TIMEZONE:-UTC}" "${LOCALE:-en_US.UTF-8}" "${SWAP_SIZE:-8}"

    print_success "Unattended installation complete!"
}

# ==============================================================================
# Main
# ==============================================================================

main() {
    case "${1:-}" in
        --help|-h)
            echo "OrionOS Installer ${VERSION}"
            echo ""
            echo "Usage:"
            echo "  $0                          Interactive installation"
            echo "  $0 --unattended <config>    Automated installation from config file"
            echo "  $0 --help                   Show this help"
            echo ""
            echo "Config file format (for unattended mode):"
            echo '  DISK="/dev/sda"'
            echo '  HOSTNAME="my-orionos"'
            echo '  USERNAME="user"'
            echo '  PASSWORD="secret"'
            echo '  TIMEZONE="America/New_York"'
            echo '  LOCALE="en_US.UTF-8"'
            echo '  SWAP_SIZE=8'
            ;;
        --unattended)
            unattended_install "${2:-}"
            ;;
        *)
            interactive_install
            ;;
    esac
}

main "$@"
