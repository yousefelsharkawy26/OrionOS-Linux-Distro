# OrionOS Cloud Sync GUI

## Overview
Graphical interface for managing cloud synchronization across multiple providers (Nextcloud, WebDAV, SFTP).

## Features
- **Multi-Provider Support**: Nextcloud, WebDAV, SFTP
- **Folder Sync**: Bidirectional and one-way sync
- **Conflict Resolution**: Configurable conflict handling
- **Encryption**: Optional end-to-end encryption
- **Bandwidth Control**: Limit sync bandwidth
- **Tray Integration**: Background sync with system tray
- **Auto-sync**: Sync on startup and file changes

## Supported Providers

### Nextcloud
- Full Nextcloud API integration
- Calendar and contacts sync
- End-to-end encryption support

### WebDAV
- Standard WebDAV protocol
- Compatible with ownCloud, Synology, etc.
- HTTP/HTTPS support

### SFTP
- SSH-based file transfer
- Key-based authentication
- Custom port support

## Usage
```bash
# Launch GUI
orionos-cloud-sync-launcher

# Or launch from terminal
orionos-cloud-sync
```

## Configuration
```json
{
    "auto_sync_startup": true,
    "sync_interval_minutes": 15,
    "bandwidth_limit_mbps": 0,
    "conflict_resolution": "ask",
    "encrypt_files": false,
    "show_in_tray": true
}
```

## Settings

### General
- Auto-sync on startup
- Sync interval
- Sync on file change
- Bandwidth limit

### Conflict Resolution
- Keep newer file
- Keep local/remote
- Ask each time

### Encryption
- AES-256-GCM
- ChaCha20-Poly1305

## CLI Companion
```bash
# Sync now
orionos-cloud-sync --sync-now

# List accounts
orionos-cloud-sync --list-accounts

# Add account
orionos-cloud-sync --add-account --type nextcloud --url https://cloud.example.com
```
