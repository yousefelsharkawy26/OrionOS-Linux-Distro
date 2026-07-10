# OrionOS Phone Sync

## Overview
OrionOS Phone Sync provides seamless integration between your OrionOS desktop and mobile devices. It enables cross-device notifications, clipboard sharing, file transfer, and more.

## Features
- **Cross-Device Notifications**: See phone notifications on desktop
- **Clipboard Sharing**: Copy/paste between devices
- **File Transfer**: Share files wirelessly
- **SMS Integration**: Read and send SMS from desktop
- **Call Management**: Answer/reject calls from desktop
- **Cloud Sync**: Sync data via cloud service

## Architecture

### Desktop Service (Rust)
- **Bluetooth**: BLE communication with mobile devices
- **Clipboard**: Bidirectional clipboard sync
- **Encryption**: End-to-end encryption for all data
- **Input**: Remote input control
- **Notifications**: Cross-device notification relay
- **Pairing**: Device pairing management
- **SMS**: SMS integration
- **Cloud**: Cloud synchronization client

### Cloud Service (Go)
- **API**: RESTful API for cloud sync
- **Authentication**: JWT-based authentication
- **Database**: PostgreSQL for data storage
- **Docker**: Containerized deployment
- **Encryption**: Server-side encryption

### Protocol Buffers
- **Schema**: `proto/sync.proto`
- **Message Types**: Notifications, clipboard, files, SMS, calls
- **Versioning**: Schema versioning for compatibility

## Usage

### Pairing Devices
1. Install OrionOS Phone Sync on mobile device
2. Enable Bluetooth on both devices
3. Open Phone Sync on desktop
4. Scan for devices and select your phone
5. Confirm pairing on both devices

### Clipboard Sharing
1. Copy text on one device
2. Paste on the other device
3. Automatic sync via Bluetooth or cloud

### File Transfer
1. Right-click file on desktop
2. Select "Send to Phone"
3. Choose paired device
4. Confirm transfer on mobile

### SMS Integration
1. Open Phone Sync on desktop
2. View SMS messages
3. Compose and send SMS

## Configuration

### Desktop Configuration
```json
{
    "bluetooth_enabled": true,
    "cloud_sync_enabled": true,
    "encryption_enabled": true,
    "auto_accept_files": false,
    "notification_filter": ["all"],
    "sms_integration": true,
    "call_management": true
}
```

### Cloud Service Configuration
```yaml
server:
  host: "0.0.0.0"
  port: 8080
  
database:
  host: "localhost"
  port: 5432
  name: "phone_sync"
  
auth:
  jwt_secret: "your-secret-key"
  token_expiry: "24h"
  
encryption:
  enabled: true
  algorithm: "AES-256-GCM"
```

## Installation

### Desktop
```bash
sudo pacman -S orionos-phone-sync
```

### Cloud Service
```bash
# Using Docker
docker-compose up -d

# Or build from source
cd ecosystem/phone-sync/cloud
go build -o phone-sync-server cmd/server/main.go
```

### Mobile
Download from:
- Android: [Google Play Store](https://play.google.com/store/apps/details?id=com.orionos.phonesync)
- iOS: [Apple App Store](https://apps.apple.com/app/orionos-phone-sync/id123456789)

## Development

### Building Desktop Service
```bash
cd ecosystem/phone-sync/desktop
cargo build --release
```

### Building Cloud Service
```bash
cd ecosystem/phone-sync/cloud
go build -o phone-sync-server cmd/server/main.go
```

### Protocol Buffers
```bash
# Generate Go code
protoc --go_out=. --go_opt=paths=source_relative proto/sync.proto

# Generate Rust code
protoc --rust_out=. proto/sync.proto
```

## Security

### End-to-End Encryption
- All data encrypted before transmission
- Keys derived from pairing process
- No data stored unencrypted

### Authentication
- JWT tokens for API access
- Device-specific keys
- Automatic token refresh

### Privacy
- Local-first approach
- Optional cloud sync
- Data minimization

## Troubleshooting

### Bluetooth Connection Issues
1. Check Bluetooth is enabled:
   ```bash
   bluetoothctl show
   ```
2. Verify device is paired:
   ```bash
   bluetoothctl devices
   ```
3. Restart Bluetooth service:
   ```bash
   sudo systemctl restart bluetooth
   ```

### Cloud Sync Issues
1. Check server status:
   ```bash
   docker-compose ps
   ```
2. Verify network connectivity:
   ```bash
   curl http://localhost:8080/health
   ```
3. Check logs:
   ```bash
   docker-compose logs -f
   ```

### File Transfer Fails
1. Verify both devices are connected
2. Check available storage space
3. Ensure file permissions are correct

## References
- [Bluetooth Documentation](https://wiki.archlinux.org/title/Bluetooth)
- [Protocol Buffers Documentation](https://developers.google.com/protocol-buffers)
- [Go Documentation](https://go.dev/doc/)
- [Rust Documentation](https://doc.rust-lang.org/book/)
