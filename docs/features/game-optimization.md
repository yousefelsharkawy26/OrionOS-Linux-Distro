# OrionOS Game Optimization

## Overview
OrionOS Game Optimization provides automatic detection and optimization of games for maximum performance. It dynamically adjusts system settings based on running games and system load.

## Features
- **Auto-Detection**: Automatically detect running games
- **Dynamic Profiles**: Switch performance profiles based on game
- **CPU Optimization**: Governor and frequency control
- **GPU Optimization**: Power management and clock speeds
- **I/O Optimization**: Scheduler and read-ahead settings
- **Network Optimization**: TCP congestion control
- **Audio Optimization**: Low-latency audio settings

## Performance Profiles

### Default
- Balanced settings for general use
- CPU governor: `schedutil`
- I/O scheduler: `mq-deadline`
- Network: Standard settings

### Gaming
- Maximum performance for gaming
- CPU governor: `performance`
- I/O scheduler: `none`
- GPU: Maximum power limit
- Network: BBR congestion control
- Audio: Low-latency settings

### Performance
- High performance for demanding applications
- CPU governor: `performance`
- I/O scheduler: `none`
- GPU: High performance mode

## Usage

### Automatic Mode
The game optimizer runs as a daemon and automatically detects games:

```bash
# Start daemon
orionos-game-optimize --daemon

# Or via systemd
systemctl --user start orionos-game-optimized
```

### Manual Control
```bash
# List available profiles
orionos-game-optimize --list-profiles

# Set profile manually
orionos-game-optimize --profile gaming

# Check current status
orionos-game-optimize --status
```

## Configuration

### Main Configuration
```json
{
    "auto_detect": true,
    "default_profile": "gaming",
    "monitor_interval": 1.0,
    "game_directories": [
        "/home/user/Games",
        "/usr/share/games",
        "/opt/steam"
    ],
    "gpu_power_management": true,
    "cpu_performance_mode": true,
    "io_optimization": true,
    "network_optimization": true,
    "audio_optimization": true
}
```

### Game Profiles
```json
{
    "gaming": {
        "name": "gaming",
        "cpu_governor": "performance",
        "gpu_profile": "maximum",
        "io_scheduler": "none",
        "vm_params": {
            "swappiness": "1",
            "dirty_ratio": "5"
        },
        "network_params": {
            "tcp_congestion_control": "bbr"
        },
        "process_priorities": {
            "game": -20,
            "audio": -15
        }
    }
}
```

## Integration

### Steam Integration
- Automatic detection of Steam games
- Proton compatibility layer optimization
- Steam overlay integration

### MangoHud Integration
- Performance overlay
- FPS limiting
- Frame timing

### GameMode Integration
- CPU/GPU governor switching
- I/O priority adjustment
- Process nice values

## Development

### Building
```bash
make packages EXTRA=orionos-game-optimize
```

### Architecture
- **Daemon**: Python-based monitoring service
- **Detection**: Process scanning and game directory monitoring
- **Optimization**: System parameter adjustment
- **Profiles**: JSON-based configuration system

### Adding Game Detection
To add detection for new games:
1. Add process names to `ignore_processes` in config
2. Add game directories to `game_directories`
3. Create custom profiles if needed

## Troubleshooting

### Games Not Detected
1. Verify game directories in config
2. Check process names in `ignore_processes`
3. Review logs in `/var/log/orionos/game-optimize.log`

### Performance Issues
1. Check current profile:
   ```bash
   orionos-game-optimize --status
   ```
2. Verify GPU drivers:
   ```bash
   nvidia-smi  # For NVIDIA
   glxinfo | grep "OpenGL renderer"  # For AMD/Intel
   ```

### I/O Settings Not Applied
1. Check permissions:
   ```bash
   sudo chmod 644 /sys/block/*/queue/scheduler
   ```
2. Verify kernel support:
   ```bash
   cat /sys/block/sda/queue/scheduler
   ```

## References
- [GameMode Documentation](https://github.com/FeralInteractive/gamemode)
- [MangoHud Documentation](https://github.com/flightlessmango/MangoHud)
- [Linux Gaming Wiki](https://wiki.archlinux.org/title/Gaming)
