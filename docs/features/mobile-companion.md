# OrionOS Mobile Companion

## Overview
Full-featured mobile device integration extending beyond basic sync to include clipboard sharing, file transfer, media control, SMS bridge, screen mirroring, and remote input.

## Features
- **Clipboard Sharing**: Copy/paste between phone and desktop
- **File Transfer**: Wirelessly send files between devices
- **Media Control**: Control desktop media from phone
- **SMS Bridge**: Read/send SMS from desktop
- **Notifications**: Cross-device notification relay
- **Remote Input**: Control desktop mouse/keyboard from phone
- **Screen Mirror**: Mirror desktop screen to phone
- **Bluetooth**: BLE-based device discovery and pairing

## Architecture

### Desktop Client (Rust)
- WebSocket server for real-time communication
- Bluetooth Low Energy for device discovery
- AES-256-GCM encryption for all data
- Async I/O with Tokio

### Cloud Relay (Go)
- RESTful API for cloud relay
- JWT authentication
- WebSocket support for real-time features
- PostgreSQL for session storage

### Protocol Buffers
- Structured message definitions
- Efficient serialization
- Versioned schema

## Usage

### Start Desktop Service
```bash
orionos-mobile-companion
orionos-mobile-companion --daemon
```

### Check Status
```bash
orionos-mobile-companion --status
```

### Bluetooth Only Mode
```bash
orionos-mobile-companion --bluetooth-only
```

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/api/v1/pair` | POST | Pair device |
| `/api/v1/clipboard` | POST | Sync clipboard |
| `/api/v1/files` | POST | Transfer files |
| `/api/v1/notifications` | POST | Send notifications |
| `/api/v1/media` | POST | Control media |
| `/api/v1/sms` | POST | SMS bridge |
| `/api/v1/remote` | POST | Remote input |
