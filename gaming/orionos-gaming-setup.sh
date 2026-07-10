#!/bin/bash
# =============================================================================
# OrionOS Gaming Stack Setup
# Comprehensive gaming support with automatic optimization
# =============================================================================

set -euo pipefail

GAMING_DIR="/usr/share/orionos/gaming"
CONFIG_DIR="/etc/orionos/gaming"
LOG_FILE="/var/log/orionos/gaming-setup.log"

log_info() {
    echo -e "\033[0;34m[INFO]\033[0m $*"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $*" >> "$LOG_FILE" 2>/dev/null || true
}

log_success() {
    echo -e "\033[0;32m[OK]\033[0m $*"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [OK] $*" >> "$LOG_FILE" 2>/dev/null || true
}

log_warn() {
    echo -e "\033[1;33m[WARN]\033[0m $*"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $*" >> "$LOG_FILE" 2>/dev/null || true
}

log_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $*" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*" >> "$LOG_FILE" 2>/dev/null || true
}

# =============================================================================
# GPU Detection and Driver Installation
# =============================================================================

detect_gpu() {
    log_info "Detecting GPU hardware..."

    local gpu_info=""

    # Check NVIDIA
    if lspci -nn | grep -i nvidia >/dev/null 2>&1; then
        gpu_info="nvidia"
        local nvidia_model="$(lspci -nn | grep -i nvidia | head -1 | sed 's/.*\[//;s/\].*//')"
        log_info "NVIDIA GPU detected: $nvidia_model"

    # Check AMD
    elif lspci -nn | grep -i 'amd\|ati' >/dev/null 2>&1; then
        gpu_info="amd"
        local amd_model="$(lspci -nn | grep -i 'amd\|ati' | head -1 | sed 's/.*\[//;s/\].*//')"
        log_info "AMD GPU detected: $amd_model"

    # Check Intel
    elif lspci -nn | grep -i 'intel.*graphics' >/dev/null 2>&1; then
        gpu_info="intel"
        log_info "Intel GPU detected"
    else
        gpu_info="unknown"
        log_warn "No dedicated GPU detected"
    fi

    echo "$gpu_info"
}

install_gpu_drivers() {
    local gpu_vendor="$1"

    log_info "Installing GPU drivers for: $gpu_vendor"

    case "$gpu_vendor" in
        nvidia)
            install_nvidia_drivers
            ;;
        amd)
            install_amd_drivers
            ;;
        intel)
            install_intel_drivers
            ;;
        *)
            log_warn "No GPU drivers to install"
            ;;
    esac
}

install_nvidia_drivers() {
    log_info "Installing NVIDIA drivers..."

    # Install NVIDIA drivers with DKMS for kernel updates
    local nvidia_packages=(
        "nvidia-dkms"
        "nvidia-utils"
        "lib32-nvidia-utils"
        "nvidia-settings"
        "cuda"
        "cudnn"
    )

    for pkg in "${nvidia_packages[@]}"; do
        if pacman -Si "$pkg" >/dev/null 2>&1; then
            log_info "Installing $pkg..."
            pacman -S --needed --noconfirm "$pkg" || log_warn "Failed to install $pkg"
        else
            log_warn "Package not available: $pkg"
        fi
    done

    # Configure NVIDIA for Wayland
    mkdir -p /etc/modprobe.d
    cat > /etc/modprobe.d/nvidia-wayland.conf << 'EOF'
# NVIDIA Wayland Configuration
options nvidia-drm modeset=1
options nvidia-drm fbdev=1
EOF

    # Enable NVIDIA services
    systemctl enable nvidia-persistenced 2>/dev/null || true

    log_success "NVIDIA drivers installed"
}

install_amd_drivers() {
    log_info "Installing AMD drivers..."

    local amd_packages=(
        "mesa"
        "lib32-mesa"
        "vulkan-radeon"
        "lib32-vulkan-radeon"
        "vulkan-icd-loader"
        "lib32-vulkan-icd-loader"
        "xf86-video-amdgpu"
        "radeontop"
        "rocm-opencl-runtime"
    )

    for pkg in "${amd_packages[@]}"; do
        if pacman -Si "$pkg" >/dev/null 2>&1; then
            log_info "Installing $pkg..."
            pacman -S --needed --noconfirm "$pkg" || log_warn "Failed to install $pkg"
        fi
    done

    log_success "AMD drivers installed"
}

install_intel_drivers() {
    log_info "Installing Intel drivers..."

    local intel_packages=(
        "mesa"
        "lib32-mesa"
        "vulkan-intel"
        "lib32-vulkan-intel"
        "vulkan-icd-loader"
        "lib32-vulkan-icd-loader"
        "intel-media-driver"
        "libva-intel-driver"
        "libva-utils"
    )

    for pkg in "${intel_packages[@]}"; do
        if pacman -Si "$pkg" >/dev/null 2>&1; then
            log_info "Installing $pkg..."
            pacman -S --needed --noconfirm "$pkg" || log_warn "Failed to install $pkg"
        fi
    done

    log_success "Intel drivers installed"
}

# =============================================================================
# Gaming Software Installation
# =============================================================================

install_gaming_software() {
    log_info "Installing gaming software..."

    # Core gaming packages
    local gaming_packages=(
        # Steam
        "steam"
        "steam-native-runtime"

        # Proton and compatibility
        "proton-ge-custom"
        "protontricks"

        # Wine
        "wine-staging"
        "wine-gecko"
        "wine-mono"
        "winetricks"
        "lib32-gnutls"
        "lib32-libpulse"

        # Vulkan support
        "vulkan-icd-loader"
        "lib32-vulkan-icd-loader"

        # DirectX compatibility
        "dxvk-bin"
        "vkd3d-proton-bin"

        # Performance tools
        "gamemode"
        "lib32-gamemode"
        "mangohud"
        "lib32-mangohud"

        # Game launchers
        "lutris"
        "heroic-games-launcher-bin"
        "bottles"

        # Gaming utilities
        "gamescope"
        "gamescope-session"
        "sc-controller"

        # OBS for streaming/recording
        "obs-studio"
        "obs-vkcapture"
        "lib32-obs-vkcapture"

        # Communication
        "discord"
        "mumble"

        # Controller support
        "joyutils"
        "sdl2"
        "lib32-sdl2"
    )

    for pkg in "${gaming_packages[@]}"; do
        if pacman -Si "$pkg" >/dev/null 2>&1; then
            log_info "Installing $pkg..."
            pacman -S --needed --noconfirm "$pkg" || log_warn "Failed to install $pkg"
        else
            log_warn "Package not available: $pkg"
        fi
    done

    log_success "Gaming software installed"
}

# =============================================================================
# Gaming Optimizations
# =============================================================================

apply_gaming_optimizations() {
    log_info "Applying gaming optimizations..."

    mkdir -p "$CONFIG_DIR"

    # Gamemode configuration
    mkdir -p /etc/gamemode
    cat > /etc/gamemode/gamemode.ini << 'EOF'
; OrionOS Gamemode Configuration
[general]
; GameMode can renice game processes
renice=10

; By default, GameMode adjusts the i/o priority of games to SCHED_ISO
desiredprof=performance

[gpu]
; Apply GPU optimizations
apply_gpu_optimisations=accept-responsibility
gpu_device=0
nv_powermizer_mode=1
amd_performance_level=high

[cpu]
; CPU governor for gaming
governor=performance

[custom]
; Custom scripts to run when entering/exiting game mode
start=/usr/share/orionos/gaming/gamemode-start.sh
end=/usr/share/orionos/gaming/gamemode-end.sh
EOF

    # MangoHud configuration
    mkdir -p /etc/MangoHud
    cat > /etc/MangoHud/MangoHud.conf << 'EOF'
# OrionOS MangoHud Configuration
fps
frametime
cpu_stats
cpu_temp
gpu_stats
gpu_temp
ram
vram
engine_version
wine
gamemode
vulkan_driver
resolution
arch
time

# Position
position=top-left

# Styling
background_alpha=0.3
font_size=18
text_color=FFFFFF
engine_color=00B4D8
vram_color=7B2FF7
ram_color=06D6A0
cpu_color=FFD166
gpu_color=FF6B6B

# Visibility
no_display
# Toggle with Shift_R+F12
toggle_hud=Shift_R+F12
toggle_fps_limit=Shift_L+F1

# Frame rate limit (0 = unlimited)
fps_limit=0
EOF

    # Gamescope configuration
    mkdir -p /etc/gamescope
    cat > /etc/gamescope/orionos-session << 'EOF'
#!/bin/bash
# OrionOS Gamescope Session
# Provides a dedicated gaming environment

export SteamDeck=1
export STEAM_RUNTIME=1

# Enable HDR if supported
export ENABLE_GAMESCOPE_WSI=1

# Gamescope options
GAMESCOPE_OPTS=""
GAMESCOPE_OPTS="$GAMESCOPE_OPTS -W 1920 -H 1080"
GAMESCOPE_OPTS="$GAMESCOPE_OPTS -r 120"
GAMESCOPE_OPTS="$GAMESCOPE_OPTS --adaptive-sync"
GAMESCOPE_OPTS="$GAMESCOPE_OPTS --hdr-enabled"
GAMESCOPE_OPTS="$GAMESCOPE_OPTS --prefer-output '*',eDP-1"

# Start Steam in gamescope
exec gamescope $GAMESCOPE_OPTS -- steam -tenfoot -steamos3
EOF
    chmod +x /etc/gamescope/orionos-session

    # Create gamemode scripts
    mkdir -p "$GAMING_DIR"

    cat > "$GAMING_DIR/gamemode-start.sh" << 'EOF'
#!/bin/bash
# OrionOS Gamemode Start Script
# Runs when entering game mode

# Disable notifications
killall -SIGUSR1 dunst 2>/dev/null || true

# Set performance governor
echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null || true

# Disable transparency in compositor
hyprctl keyword decoration:blur:enabled false 2>/dev/null || true
hyprctl keyword decoration:shadow:enabled false 2>/dev/null || true

# Boost network for gaming
ethtool -K eth0 gro off gso off tso off 2>/dev/null || true

# Notify
notify-send "GameMode" "Gaming optimizations enabled" -i input-gaming -a "OrionOS Gaming"
EOF
    chmod +x "$GAMING_DIR/gamemode-start.sh"

    cat > "$GAMING_DIR/gamemode-end.sh" << 'EOF'
#!/bin/bash
# OrionOS Gamemode End Script
# Runs when exiting game mode

# Re-enable notifications
killall -SIGUSR2 dunst 2>/dev/null || true

# Restore balanced governor
echo schedutil | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null || true

# Re-enable compositor effects
hyprctl keyword decoration:blur:enabled true 2>/dev/null || true
hyprctl keyword decoration:shadow:enabled true 2>/dev/null || true

# Notify
notify-send "GameMode" "Gaming optimizations disabled" -i input-gaming -a "OrionOS Gaming"
EOF
    chmod +x "$GAMING_DIR/gamemode-end.sh"

    log_success "Gaming optimizations applied"
}

# =============================================================================
# Wine Configuration
# =============================================================================

setup_wine() {
    log_info "Setting up Wine environment..."

    # Create default Wine prefix with optimizations
    mkdir -p /etc/skel/.wine

    # Wine registry optimizations
    cat > /etc/skel/.wine/user.reg << 'EOF'
WINE REGISTRY Version 2

[Software\\Wine\\Direct3D]
"DirectDrawRenderer"="vulkan"
"OffscreenRenderingMode"="fbo"
"VideoMemorySize"="4096"
"UseGLSL"="enabled"
"csrf"="disabled"

[Software\\Wine\\DirectInput]
"MouseWarpOverride"="enable"

[Software\\Wine\\X11 Driver]
"UseXIM"="false"
"Decorated"="N"
"Managed"="N"

[Software\\Wine\\Explorer]
"Desktop"="Default"
EOF

    # Winetricks default packages
    cat > "$GAMING_DIR/winetricks-defaults.txt" << 'EOF'
# Default Winetricks packages for gaming
# Run: winetricks < package.txt

# Core fonts
corefonts

# DirectX
dxvk
vkd3d

# Visual C++ runtimes
vcrun2019
vcrun2022

# .NET Framework
dotnet48

# Common dependencies
msls31
msxml3
msxml6
EOF

    log_success "Wine environment configured"
}

# =============================================================================
# Steam Configuration
# =============================================================================

setup_steam() {
    log_info "Setting up Steam..."

    mkdir -p /etc/skel/.config/steam

    # Steam launch options for better compatibility
    cat > "$CONFIG_DIR/steam-launch-options.md" << 'EOF'
# OrionOS Recommended Steam Launch Options

## General Performance
```
GAMEPERFORMANCE="gamemoderun %command%"
MANGOHUD="mangohud %command%"
GAMESCOPE="gamescope -w 1920 -h 1080 -r 120 -- %command%"
```

## Proton Configuration
```
PROTON_USE_WINED3D=0     # Use DXVK (default)
PROTON_NO_ESYNC=0        # Enable esync
PROTON_NO_FSYNC=0        # Enable fsync
PROTON_ENABLE_NVAPI=1    # Enable NVIDIA DLSS
PROTON_HIDE_NVIDIA_GPU=0 # Show real GPU
```

## Common Launch Options
```
# Performance mode
gamemoderun mangohud %command%

# With Gamescope (for HDR/VRR)
gamescope -W 1920 -H 1080 -r 120 -- mangohud %command%

# For older games (disable composition)
mangohud %command% --no-sandbox
```

## Environment Variables
- `MANGOHUD=1` - Enable MangoHud
- `GAMEMODE=1` - Enable GameMode
- `ENABLE_VKBASALT=1` - Enable vkBasalt
- `DXVK_HUD=compiler` - Show DXVK shader compilation
EOF

    log_success "Steam configured"
}

# =============================================================================
# Automatic Game Optimization Database
# =============================================================================

create_game_database() {
    log_info "Creating game optimization database..."

    cat > "$CONFIG_DIR/game-optimizations.json" << 'EOF'
{
    "version": "0.1.0",
    "games": {
        "cs2": {
            "name": "Counter-Strike 2",
            "launch_options": "gamemoderun mangohud %command% -novid -nojoy",
            "cpu_priority": "high",
            "gpu_profile": "performance",
            "environment": {
                "MANGOHUD_CONFIG": "fps,frametime,cpu_stats,gpu_stats"
            }
        },
        "dota2": {
            "name": "Dota 2",
            "launch_options": "gamemoderun mangohud %command% -novid -nojoy",
            "cpu_priority": "high",
            "gpu_profile": "performance"
        },
        "eldenring": {
            "name": "Elden Ring",
            "launch_options": "gamemoderun mangohud %command%",
            "environment": {
                "WINE_CPU_TOPOLOGY": "auto",
                "PROTON_USE_WINED3D": "0"
            }
        },
        "witcher3": {
            "name": "The Witcher 3",
            "launch_options": "gamemoderun mangohud %command%",
            "environment": {
                "DXVK_ASYNC": "1"
            }
        },
        "cyberpunk2077": {
            "name": "Cyberpunk 2077",
            "launch_options": "gamemoderun mangohud %command% --launcher-skip",
            "environment": {
                "PROTON_ENABLE_NVAPI": "1",
                "PROTON_HIDE_NVIDIA_GPU": "0",
                "VKD3D_CONFIG": "dxr,dxr11"
            }
        },
        "valorant": {
            "name": "Valorant",
            "launch_options": "gamemoderun mangohud %command%",
            "cpu_priority": "high",
            "environment": {
                "MESA_GLTHREAD": "true"
            }
        },
        "overwatch": {
            "name": "Overwatch 2",
            "launch_options": "gamemoderun mangohud %command%",
            "environment": {
                "PROTON_USE_WINED3D": "0",
                "PROTON_NO_ESYNC": "1"
            }
        },
        "apex": {
            "name": "Apex Legends",
            "launch_options": "gamemoderun mangohud %command% +fps_max 0",
            "cpu_priority": "high"
        },
        "minecraft": {
            "name": "Minecraft",
            "launch_options": "gamemoderun mangohud %command%",
            "environment": {
                "MESA_GL_VERSION_OVERRIDE": "4.6",
                "MESA_GLSL_VERSION_OVERRIDE": "460"
            }
        },
        "rocketleague": {
            "name": "Rocket League",
            "launch_options": "gamemoderun mangohud %command% -high",
            "cpu_priority": "high"
        }
    }
}
EOF

    # Game launcher script
    cat > "$GAMING_DIR/orionos-game-launcher" << 'EOF'
#!/usr/bin/env python3
"""
OrionOS Game Launcher
Automatically applies game-specific optimizations
"""

import json
import os
import subprocess
import sys
from pathlib import Path

CONFIG_DIR = Path("/etc/orionos/gaming")
GAMING_DIR = Path("/usr/share/orionos/gaming")

def load_game_database():
    db_path = CONFIG_DIR / "game-optimizations.json"
    if db_path.exists():
        return json.loads(db_path.read_text())
    return {"games": {}}

def find_game(appid=None, name=None):
    db = load_game_database()
    games = db.get("games", {})

    if appid:
        return games.get(appid)

    if name:
        for game_id, game_info in games.items():
            if game_info["name"].lower() == name.lower():
                return game_info

    return None

def launch_game(game_info, original_command):
    """Launch a game with optimizations"""
    env = os.environ.copy()

    # Apply environment variables
    if "environment" in game_info:
        for key, value in game_info["environment"].items():
            env[key] = value

    # Build launch command
    launch_options = game_info.get("launch_options", "")
    command = launch_options.replace("%command%", original_command)

    print(f"[OrionOS] Launching with optimizations: {command}")

    # Set CPU priority
    cpu_priority = game_info.get("cpu_priority", "normal")
    if cpu_priority == "high":
        command = f"nice -n -5 {command}"
    elif cpu_priority == "realtime":
        command = f"chrt -r 99 {command}"

    # Launch the game
    process = subprocess.Popen(
        command,
        shell=True,
        env=env,
        cwd=os.getcwd()
    )

    return process.wait()

def main():
    import argparse
    parser = argparse.ArgumentParser(description='OrionOS Game Launcher')
    parser.add_argument('--appid', help='Steam AppID')
    parser.add_argument('--name', help='Game name')
    parser.add_argument('command', nargs='?', help='Original launch command')

    args = parser.parse_args()

    game = find_game(args.appid, args.name)

    if game:
        print(f"[OrionOS] Found optimization profile: {game['name']}")
        sys.exit(launch_game(game, args.command or ""))
    else:
        # Run without optimizations
        if args.command:
            sys.exit(subprocess.run(args.command, shell=True).returncode)
        else:
            print("No game specified. Use --appid or --name")
            sys.exit(1)

if __name__ == '__main__':
    main()
EOF
    chmod +x "$GAMING_DIR/orionos-game-launcher"

    log_success "Game optimization database created"
}

# =============================================================================
# HDR and VRR Setup
# =============================================================================

setup_display_features() {
    log_info "Setting up HDR and VRR..."

    # Check for HDR support
    cat > "$GAMING_DIR/check-hdr.sh" << 'EOF'
#!/bin/bash
# Check HDR capabilities

echo "OrionOS HDR Detection"
echo "====================="

# Check if running on Wayland with HDR support
if [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
    echo "Session: Wayland ✓"

    # Check compositor HDR support
    if command -v hyprctl &>/dev/null; then
        echo "Compositor: Hyprland"
        # Check if HDR is enabled
        hyprctl monitors | grep -q "hdr" && echo "HDR: Supported ✓" || echo "HDR: Not detected"
    fi
else
    echo "Session: X11 (HDR requires Wayland)"
fi

# Check VRR/FreeSync/G-Sync
if [[ -f /sys/class/drm/card0/device/power_dpm_force_performance_level ]]; then
    echo "GPU: AMD/Intel"
    cat /sys/class/drm/card0/device/power_dpm_force_performance_level
fi

if command -v nvidia-settings &>/dev/null; then
    echo "GPU: NVIDIA"
    nvidia-settings -q AllowVRR 2>/dev/null || echo "VRR: Check nvidia-settings"
fi
EOF
    chmod +x "$GAMING_DIR/check-hdr.sh"

    log_success "Display features configured"
}

# =============================================================================
# FSR and Upscaling Configuration
# =============================================================================

setup_upscaling() {
    log_info "Setting up upscaling technologies..."

    cat > "$CONFIG_DIR/upscaling-profiles.json" << 'EOF'
{
    "profiles": {
        "quality": {
            "name": "Quality",
            "description": "Best image quality with moderate performance gain",
            "fsr_sharpness": 0.8,
            "render_scale": 1.0
        },
        "balanced": {
            "name": "Balanced",
            "description": "Good balance between quality and performance",
            "fsr_sharpness": 0.6,
            "render_scale": 0.75
        },
        "performance": {
            "name": "Performance",
            "description": "Maximum performance with acceptable quality",
            "fsr_sharpness": 0.4,
            "render_scale": 0.5
        },
        "ultra_performance": {
            "name": "Ultra Performance",
            "description": "Maximum performance for low-end hardware",
            "fsr_sharpness": 0.2,
            "render_scale": 0.33
        }
    }
}
EOF

    log_success "Upscaling profiles configured"
}

# =============================================================================
# Main Setup
# =============================================================================

main() {
    echo "========================================"
    echo "OrionOS Gaming Stack Setup"
    echo "========================================"

    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi

    mkdir -p "$GAMING_DIR" "$CONFIG_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"

    log_info "Starting gaming stack setup..."

    # Detect and install GPU drivers
    GPU_VENDOR=$(detect_gpu)
    install_gpu_drivers "$GPU_VENDOR"

    # Install gaming software
    install_gaming_software

    # Apply optimizations
    apply_gaming_optimizations

    # Setup Wine
    setup_wine

    # Setup Steam
    setup_steam

    # Create game database
    create_game_database

    # Setup display features
    setup_display_features

    # Setup upscaling
    setup_upscaling

    # Enable services
    systemctl enable gamemoded --now 2>/dev/null || true

    echo ""
    echo "========================================"
    log_success "OrionOS Gaming Stack setup complete!"
    echo "========================================"
    echo ""
    echo "Next steps:"
    echo "  1. Reboot to load GPU drivers"
    echo "  2. Launch Steam and enable Proton"
    echo "  3. Add 'gamemoderun %command%' to game launch options"
    echo "  4. Install games and enjoy!"
    echo ""
}

main "$@"
