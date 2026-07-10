# OrionOS Display Optimization

## Overview
OrionOS Display Optimization provides automatic configuration and optimization of displays, including HDR, VRR (Variable Refresh Rate), and color management.

## Features
- **HDR Support**: High Dynamic Range configuration
- **VRR Support**: Variable Refresh Rate (FreeSync/G-Sync)
- **Color Management**: ICC profiles and color calibration
- **Ambient Light Adaptation**: Auto brightness adjustment
- **Blue Light Filter**: Night mode for eye comfort
- **Multi-Monitor**: Multi-display management

## Display Profiles

### Default
- Standard SDR settings
- 60Hz refresh rate
- sRGB color space

### HDR
- High Dynamic Range enabled
- 10-bit color depth
- Rec.2020 color space
- Enhanced brightness and contrast

### VRR
- Variable Refresh Rate enabled
- Adaptive sync
- Reduced screen tearing

### HDR+VRR
- Combined HDR and VRR
- Maximum visual quality
- Smooth gameplay

### Gaming
- Maximum refresh rate
- HDR enabled
- Low latency mode
- Enhanced color saturation

### Productivity
- Comfortable brightness
- Blue light filter
- Eye care mode

## Usage

### Automatic Mode
```bash
# Start display optimization daemon
orionos-display-optimization --daemon

# Or via systemd
systemctl --user start orionos-display-optimized
```

### Manual Control
```bash
# List available profiles
orionos-display-optimization --list-profiles

# Set profile manually
orionos-display-optimization --profile gaming

# Detect connected displays
orionos-display-optimization --detect-displays
```

## Configuration

### Main Configuration
```json
{
    "auto_detect": true,
    "default_profile": "gaming",
    "monitor_interval": 2.0,
    "hdr_support": true,
    "vrr_support": true,
    "color_management": true,
    "ambient_light_adaptation": true
}
```

### Display Profiles
```json
{
    "gaming": {
        "name": "gaming",
        "hdr_enabled": true,
        "vrr_enabled": true,
        "refresh_rate": 165,
        "color_depth": 10,
        "color_space": "Rec.2020",
        "gamma": 2.4,
        "brightness": 1.0,
        "contrast": 1.3,
        "saturation": 1.2,
        "sharpness": 1.1
    }
}
```

## HDR Setup

### Requirements
- HDR-capable display
- NVIDIA (Turing+) or AMD (RDNA+) GPU
- DisplayPort 1.4 or HDMI 2.1
- HDR content

### Configuration
1. Enable HDR in display settings:
   ```bash
   xrandr --output DP-1 --set HDR 1
   ```

2. Set color depth:
   ```bash
   xrandr --output DP-1 --set ColorDepth 10
   ```

3. Set color space:
   ```bash
   xrandr --output DP-1 --set ColorSpace "Rec.2020"
   ```

## VRR Setup

### Requirements
- FreeSync or G-Sync compatible display
- Compatible GPU (AMD/NVIDIA)
- DisplayPort or HDMI connection

### Configuration
1. Enable VRR:
   ```bash
   xrandr --output DP-1 --set VRR 1
   ```

2. Verify refresh rate:
   ```bash
   xrandr --output DP-1 --verbose | grep Refresh
   ```

## Color Management

### ICC Profiles
```bash
# Install color management tools
sudo pacman -S argyllcms displaycal

# Calibrate display
dispcal -v -d1

# Install ICC profile
sudo cp profile.icc /usr/share/color/icc/
```

### Night Mode
```bash
# Enable blue light filter
orionos-display-optimization --profile productivity
```

## Development

### Building
```bash
make packages EXTRA=orionos-display-optimization
```

### Architecture
- **Daemon**: Python-based monitoring service
- **Detection**: xrandr display detection
- **Optimization**: Display parameter adjustment
- **Profiles**: JSON-based configuration system

### Adding Display Support
To add support for new displays:
1. Add display to `ignore_displays` if needed
2. Create custom profile for display capabilities
3. Test with different GPU drivers

## Troubleshooting

### HDR Not Working
1. Check display capabilities:
   ```bash
   xrandr --output DP-1 --verbose | grep HDR
   ```

2. Verify GPU driver:
   ```bash
   nvidia-smi  # For NVIDIA
   glxinfo | grep "OpenGL renderer"  # For AMD/Intel
   ```

3. Check cable connection:
   - Use DisplayPort 1.4 or HDMI 2.1
   - Avoid adapters if possible

### VRR Not Working
1. Verify display supports FreeSync/G-Sync
2. Check refresh rate:
   ```bash
   xrandr --output DP-1 --verbose | grep Refresh
   ```

3. Enable in display OSD menu

### Color Issues
1. Verify ICC profile:
   ```bash
   dispwin -I profile.icc
   ```

2. Check color depth:
   ```bash
   xrandr --output DP-1 --verbose | grep Depth
   ```

## References
- [HDR on Linux](https://wiki.archlinux.org/title/HDR)
- [Variable Refresh Rate](https://wiki.archlinux.org/title/Variable_refresh_rate)
- [Color Management](https://wiki.archlinux.org/title/Color_management)
- [xrandr Documentation](https://www.x.org/releases/current/doc/man/man1/xrandr.1.xhtml)
