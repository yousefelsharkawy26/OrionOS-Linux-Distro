# OrionOS Containerized Applications

## Overview
Docker, Podman, and Distrobox integration for running containerized applications with full desktop integration.

## Supported Runtimes
- **Docker**: Full Docker Engine with BuildKit
- **Podman**: Rootless container runtime
- **Distrobox**: Container-based dev environments with desktop integration

## Usage

### Setup
```bash
sudo orionos-containers-setup setup
```

### Launch Container Apps
```bash
# List available apps
orionos-containers-launch list

# Launch a container app
orionos-containers-launch app gimp
orionos-containers-launch app code
```

### Distrobox
```bash
# Create a distrobox
orionos-distrobox-manager create mydev docker.io/library/ubuntu:24.04

# Enter distrobox
orionos-distrobox-manager enter mydev

# Export apps to desktop
orionos-distrobox-manager export mydev
```

### Status
```bash
orionos-containers-setup status
```
