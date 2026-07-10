# OrionOS Desktop Architecture

## Overview

The OrionOS desktop environment is built around Hyprland, a dynamic tiling Wayland compositor, with a custom shell that provides a macOS-inspired user experience while maintaining a distinct identity.

## Design Philosophy

- **Smooth**: All animations target 120 FPS
- **Minimal**: Clean, uncluttered interface
- **Functional**: Every element serves a purpose
- **Adaptable**: Responds to context and time
- **Beautiful**: Premium visual design

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        Display Server                        │
│                          Wayland                             │
├─────────────────────────────────────────────────────────────┤
│                     Compositor: Hyprland                     │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐   │
│  │  Tiling  │ │ Floating │ │  Gestures│ │  Animations  │   │
│  │  Layout  │ │  Windows │ │  Input   │ │  120 FPS     │   │
│  └──────────┘ └──────────┘ └──────────┘ └──────────────┘   │
├─────────────────────────────────────────────────────────────┤
│                        Shell Components                      │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐   │
│  │  Waybar  │ │  Rofi    │ │  Dunst   │ │  Swww        │   │
│  │ (Top Bar)│ │ (Launcher│ │(Notify)  │ │ (Wallpaper)  │   │
│  └──────────┘ └──────────┘ └──────────┘ └──────────────┘   │
├─────────────────────────────────────────────────────────────┤
│                      Theming System                          │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐   │
│  │  GTK     │ │  Icons   │ │  Cursor  │ │  Plymouth    │   │
│  │  Theme   │ │  Theme   │ │  Theme   │ │  Boot Theme  │   │
│  └──────────┘ └──────────┘ └──────────┘ └──────────────┘   │
├─────────────────────────────────────────────────────────────┤
│                     Application Layer                        │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐   │
│  │  Firefox │ │  Alacritty│ │  Dolphin │ │  Clipboard   │   │
│  │  (Web)   │ │ (Terminal)│ │ (Files)  │ │  Manager     │   │
│  └──────────┘ └──────────┘ └──────────┘ └──────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Window Manager: Hyprland

### Key Features

| Feature | Implementation | Config |
|---------|---------------|--------|
| Tiling | Dwindle layout | `general.layout = dwindle` |
| Floating | Drag + resize | `windowrule = float, class` |
| Workspaces | Dynamic | 10 default workspaces |
| Multi-monitor | Per-monitor config | `monitor = name,res,offset,scale` |
| Animations | Bezier curves | `animations` block |
| Gestures | Touchpad swipe | `gestures` block |
| HDR | Color management | `experimental:hdr = true` |
| VRR | Adaptive sync | `misc:vrr = 1` |

### Animation Configuration

```ini
animations {
    enabled = true
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05

    animation = windows, 1, 7, myBezier
    animation = windowsOut, 1, 7, default, popin 80%
    animation = border, 1, 10, default
    animation = fade, 1, 7, default
    animation = workspaces, 1, 6, default
}
```

All animations use hardware acceleration through OpenGL, targeting 120 FPS on capable displays.

### Workspace Management

- **Static workspaces**: 1-10 with keyboard shortcuts
- **Dynamic workspaces**: Auto-created on demand
- **Per-monitor**: Independent workspace sets
- **Window rules**: Auto-assign apps to workspaces

## Top Bar: Waybar

### Design

- Height: 40px
- Position: Top
- Margin: 8px top, 16px sides
- Style: Blur backdrop, rounded corners
- Font: SF Pro Display 13px

### Modules

| Position | Module | Description |
|----------|--------|-------------|
| Left | Workspaces | Workspace indicators |
| Left | Window | Active window title |
| Center | Clock | Date and time |
| Right | Network | WiFi/Ethernet status |
| Right | CPU | CPU usage |
| Right | Memory | RAM usage |
| Right | Temperature | System temperature |
| Right | Battery | Battery level |
| Right | Audio | Volume level |
| Right | Tray | System tray |

### Styling

```css
window#waybar {
    background: rgba(15, 15, 35, 0.75);
    border-radius: 12px;
    border: 1px solid rgba(255, 255, 255, 0.1);
    backdrop-filter: blur(20px);
}
```

## Application Launcher: Rofi

### Design

- Width: 800px
- Height: 500px
- Border radius: 20px
- Blur backdrop
- Show icons

### Modes

- **drun**: Desktop applications
- **run**: Command execution
- **window**: Window switching
- **clipboard**: Clipboard history

### Configuration

```rasi
configuration {
    modi: "drun,run,window";
    show-icons: true;
    icon-theme: "OrionOS";
    font: "SF Pro Display 12";
}
```

## Notification Daemon: Dunst

### Design

- Width: 400px
- Max height: 150px
- Border radius: 16px
- Blur effect
- Limit: 5 notifications

### Features

- **Urgency levels**: Low, Normal, Critical
- **Actions**: Click to dismiss, middle-click for action
- **Icons**: Application icons
- **History**: Last 20 notifications

### Configuration

```ini
[global]
    width = 400
    height = 150
    origin = top-right
    offset = 20x60
    transparency = 20
    frame_width = 2
    frame_color = "#00b4d8"
    font = SF Pro Display 11
    corner_radius = 16
```

## Lock Screen: Swaylock Effects

### Design

- Blur: 10x5
- Vignette: 0.5:0.5
- Background color: OrionOS dark (#0f0f23)
- Indicator: Ring style with 120px radius

### Features

- **Clock**: Shows current time
- **Blur**: Desktop blur effect
- **Vignette**: Edge darkening
- **Grace period**: Short unlock window after sleep

## Wallpaper: Swww

### Dynamic Wallpapers

OrionOS includes dynamic wallpapers that change based on time:

```
/usr/share/backgrounds/orionos/dynamic/
├── morning.jpg    (6:00 - 12:00)
├── afternoon.jpg  (12:00 - 17:00)
├── evening.jpg    (17:00 - 20:00)
└── night.jpg      (20:00 - 6:00)
```

### Transition

```bash
# Smooth fade transition
swww img wallpaper.jpg --transition-type fade --transition-duration 2
```

## Theming System

### Color Palette

| Name | Hex | Usage |
|------|-----|-------|
| Orion Blue | #00B4D8 | Primary accent |
| Orion Purple | #7B2FF7 | Secondary accent |
| Orion Coral | #FF6B6B | Error/danger |
| Orion Gold | #FFD166 | Warning |
| Orion Green | #06D6A0 | Success |
| BG Primary | #0F0F23 | Main background |
| BG Secondary | #1A1A3E | Elevated surfaces |
| Text Primary | #F0F0FF | Main text |
| Text Secondary | #A0A0C0 | Secondary text |

### GTK Theme

- Name: OrionOS-Dark
- Based on: Custom design
- Coverage: GTK3, GTK4, libadwaita

### Icon Theme

- Name: OrionOS
- Base: Papirus (fallback)
- Style: Flat, modern

### Cursor Theme

- Name: OrionOS-Cursor
- Base: Breeze (fallback)
- Style: Smooth, animated

## Input Configuration

### Touchpad

```ini
input {
    touchpad {
        natural_scroll = true
        tap-to-click = true
        drag_lock = true
    }
    sensitivity = 0
    accel_profile = flat
}
```

### Gestures

| Gesture | Action |
|---------|--------|
| 3-finger swipe up | Mission Control |
| 3-finger swipe down | Show desktop |
| 3-finger swipe left/right | Switch workspace |
| 4-finger tap | Launchpad |

## Performance Targets

| Metric | Target | Measurement |
|--------|--------|-------------|
| Animation FPS | 120 | GPU frame times |
| Window open | < 50ms | Time to render |
| Workspace switch | < 16ms | Single frame |
| Memory usage | < 500MB | Idle desktop |
| Boot to desktop | < 10s | Cold boot |

## Accessibility

- High contrast mode
- Large text option
- Reduced motion
- Screen reader support (Orca)
- Keyboard navigation

## Future Enhancements

- [ ] Plugin system for widgets
- [ ] Advanced gesture recognition
- [ ] AI-powered window management
- [ ] VR workspace support
- [ ] Remote desktop integration
