# OrionOS Phone Sync

Phone synchronization application for OrionOS, enabling cross-device functionality similar to Apple's Continuity and Android's Nearby Share.

## Features

- **Cross-device clipboard**: Copy on one device, paste on another
- **File sharing**: Send files between devices
- **Notification sync**: Receive phone notifications on your desktop
- **Universal control**: Use your phone as a secondary input device
- **SMS messaging**: Send and receive SMS from desktop
- **Call integration**: Answer calls from desktop
- **End-to-end encryption**: Secure communication between devices

## Architecture

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  Mobile App │    │  Desktop    │    │  Cloud      │
│  (Android)  │◄──►│  Service    │◄──►│  Service    │
└─────────────┘    └─────────────┘    └─────────────┘
       ▲                  ▲                  ▲
       │                  │                  │
       ▼                  ▼                  ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  Bluetooth  │    │  Local     │    │  Internet   │
│  LE         │    │  Network   │    │             │
└─────────────┘    └─────────────┘    └─────────────┘
```

## Components

### 1. Mobile Application (Android)
- **Language**: Kotlin
- **Minimum SDK**: 26 (Android 8.0)
- **Target SDK**: 34 (Android 14)
- **Dependencies**:
  - AndroidX
  - Jetpack Compose
  - Bluetooth LE
  - WiFi Direct
  - Firebase Cloud Messaging
  - Protocol Buffers

### 2. Desktop Service
- **Language**: Rust
- **Dependencies**:
  - BlueZ (Bluetooth)
  - NetworkManager
  - DBus
  - Tokio (async runtime)
  - Serde (serialization)
  - Protocol Buffers

### 3. Cloud Service
- **Language**: Go
- **Database**: PostgreSQL
- **Message Queue**: NATS
- **Authentication**: OAuth2 + JWT
- **API**: gRPC + REST

## Protocol

Communication between devices uses Protocol Buffers for message serialization with end-to-end encryption.

### Message Types

```protobuf
syntax = "proto3";

package orionos.sync;

message ClipboardContent {
  string text = 1;
  bytes binary_data = 2;
  repeated FileMetadata files = 3;
}

message FileMetadata {
  string name = 1;
  uint64 size = 2;
  string mime_type = 3;
  bytes thumbnail = 4;
}

message Notification {
  string id = 1;
  string app_name = 2;
  string title = 3;
  string text = 4;
  bytes icon = 5;
  uint64 timestamp = 6;
  map<string, string> actions = 7;
}

message SMSMessage {
  string id = 1;
  string phone_number = 2;
  string text = 3;
  uint64 timestamp = 4;
  bool incoming = 5;
}

message DeviceInfo {
  string device_id = 1;
  string device_name = 2;
  string device_type = 3; // "phone", "desktop", "tablet"
  string os_version = 4;
  string app_version = 5;
  repeated string capabilities = 6;
}

message SyncRequest {
  DeviceInfo sender = 1;
  DeviceInfo receiver = 2;
  oneof payload {
    ClipboardContent clipboard = 3;
    FileMetadata file = 4;
    Notification notification = 5;
    SMSMessage sms = 6;
    bytes input_event = 7;
  }
}
```

## Security

- **End-to-end encryption**: All messages encrypted with libsodium
- **Device pairing**: QR code or Bluetooth LE pairing
- **Key exchange**: X25519 for key agreement
- **Message authentication**: HMAC-SHA256
- **Forward secrecy**: Ephemeral keys for each session

## Build Instructions

### Mobile App

```bash
cd mobile
./gradlew build
```

### Desktop Service

```bash
cd desktop
cargo build --release
```

### Cloud Service

```bash
cd cloud
go build ./cmd/server
```

## Installation

### Desktop

```bash
# Install the desktop service
sudo cp desktop/target/release/orionos-phone-sync /usr/bin/

# Install systemd service
sudo cp ecosystem/phone-sync/orionos-phone-sync.service /usr/lib/systemd/user/

# Enable and start
systemctl --user enable orionos-phone-sync
systemctl --user start orionos-phone-sync
```

### Mobile

```bash
# Build and install APK
./gradlew installDebug
```

## Configuration

### Desktop

Configuration file at `~/.config/orionos/phone-sync.conf`:

```ini
[general]
device_name = My OrionOS Desktop
discovery_mode = auto  # auto, bluetooth, wifi, cloud

[security]
pairing_method = qr  # qr, bluetooth
encryption_enabled = true

[cloud]
enabled = true
server_url = https://sync.orionos.org

[bluetooth]
enabled = true

[wifi]
enabled = true
```

## Development

### Requirements

- Android Studio (for mobile development)
- Rust toolchain (for desktop service)
- Go toolchain (for cloud service)
- Protocol Buffer compiler

### Code Generation

```bash
# Generate Protocol Buffers
protoc --go_out=. --go_opt=paths=source_relative \
    --go-grpc_out=. --go-grpc_opt=paths=source_relative \
    proto/sync.proto

protoc --java_out=mobile/app/src/main/java \
    --kotlin_out=mobile/app/src/main/java \
    proto/sync.proto

protoc --rust_out=desktop/src/proto \
    --grpc-rust_out=desktop/src/proto \
    proto/sync.proto
```

## Roadmap

### v0.2.0 (Beta)
- [ ] Basic clipboard sharing
- [ ] File transfer (small files)
- [ ] Notification mirroring
- [ ] Bluetooth LE discovery
- [ ] WiFi Direct transfer

### v0.3.0
- [ ] SMS messaging integration
- [ ] Call notification
- [ ] Universal control (mouse/keyboard)
- [ ] End-to-end encryption
- [ ] Cloud sync fallback

### v1.0.0
- [ ] Contact sync
- [ ] Photo sync
- [ ] App data sync
- [ ] Cross-device authentication
- [ ] Performance optimizations
