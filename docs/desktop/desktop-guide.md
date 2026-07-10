# OrionOS Desktop Guide

## Overview
OrionOS uses Hyprland as its window manager, providing a modern, fluid, and highly customizable desktop experience with macOS-inspired design elements.

## Desktop Features

### Hyprland Window Manager
- Smooth 120 FPS animations
- Tiling window management
- Dynamic workspaces
- Gesture support
- Window rules and layouts

### Top Bar (Waybar)
- System tray
- Clock and calendar
- Audio controls
- Network status
- Battery indicator
- Custom widgets

### Application Launcher (Rofi)
- Application search
- System commands
- Window switching
- Custom modes

## Configuration

### Hyprland Config
Location: `~/.config/hypr/hyprland.conf`

```bash
monitor = , preferred, auto, 1
input { kb_layout = us; follow_mouse = 1; touchpad { natural_scroll = yes; } }
general { gaps_in = 5; gaps_out = 10; border_size = 2; layout = dwindle; }
decoration { rounding = 10; blur { enabled = yes; size = 3; passes = 1; } }
animations { enabled = yes; bezier = ease, 0.25, 0.1, 0.25, 1.05; }
$mod = SUPER
bind = $mod, Return, exec, kitty
bind = $mod, Q, killactive
bind = $mod, V, togglefloating
bind = $mod, D, exec, rofi -show drun
```

### Waybar Config
Location: `~/.config/waybar/config`

```json
{
    "layer": "top",
    "position": "top",
    "height": 30,
    "modules-left": ["hyprland/workspaces"],
    "modules-center": ["hyprland/window"],
    "modules-right": ["pulseaudio", "network", "battery", "clock"]
}
```

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Super + Return` | Open terminal |
| `Super + Q` | Close window |
| `Super + V` | Toggle floating |
| `Super + D` | Open launcher |
| `Super + 1-9` | Switch workspace |
| `Super + Shift + 1-9` | Move window to workspace |

## Further Reading

- [Hyprland Wiki](https://wiki.hyprland.org/)
- [Waybar Wiki](https://github.com/Alexays/Waybar)
