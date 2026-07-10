# OrionOS Cloud Gaming

## Overview
Cloud gaming integration with Sunshine, Moonlight, Steam Remote Play, and Parsec for streaming games from desktop to any device.

## Supported Backends
- **Sunshine**: Open-source game streaming server
- **Moonlight**: NVIDIA GameStream-compatible client
- **Steam Remote Play**: Valve's streaming technology
- **Parsec**: Low-latency cloud gaming

## Usage

### Setup
```bash
orionos-cloud-gaming-setup setup
```

### Start Streaming Server
```bash
orionos-cloud-gaming-stream server
```

### Connect Client
```bash
orionos-cloud-gaming-stream connect 192.168.1.100 balanced
```

### Streaming Profiles
```bash
orionos-cloud-gaming-stream profiles
```

| Profile | Resolution | FPS | Bitrate | Best For |
|---------|-----------|-----|---------|----------|
| Ultra | 4K | 120 | 100Mbps | Local network |
| High | 1440p | 90 | 50Mbps | Fast WiFi |
| Balanced | 1080p | 60 | 20Mbps | Most users |
| Performance | 1080p | 60 | 10Mbps | Slow network |
| Mobile | 720p | 30 | 5Mbps | Mobile data |

### Status
```bash
orionos-cloud-gaming-setup status
```
