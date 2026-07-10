# OrionOS Update System

## Overview

OrionOS implements an atomic update system inspired by ChromeOS, featuring A/B updates, automatic rollback, and snapshot-based recovery. This ensures system stability and provides a safety net for failed updates.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Bootloader (GRUB)                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │  Slot A      │  │  Slot B      │  │  Recovery        │  │
│  │  (Current)   │  │  (Update)    │  │  (Snapshots)     │  │
│  └──────────────┘  └──────────────┘  └──────────────────┘  │
├─────────────────────────────────────────────────────────────┤
│                     Filesystem (Btrfs)                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │  @ (root)    │  │  @home       │  │  @snapshots      │  │
│  │  Active slot │  │  User data   │  │  Recovery points │  │
│  └──────────────┘  └──────────────┘  └──────────────────┘  │
├─────────────────────────────────────────────────────────────┤
│                     Update Service                           │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐   │
│  │  Check   │ │  Download│ │  Verify  │ │  Apply       │   │
│  │  Updates │ │  Packages│ │  Signatures│ │  Atomic    │   │
│  └──────────┘ └──────────┘ └──────────┘ └──────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## A/B Update System

### How It Works

1. System boots from **Slot A** (current)
2. Updates are applied to **Slot B** (inactive)
3. On next boot, system switches to **Slot B**
4. If boot fails, automatically rollback to **Slot A**

### Slot Management

```bash
# View current slot
grub-editenv /boot/grub/grubenv list | grep orionos_slot

# Slots are tracked via GRUB environment variables:
# orionos_slot=A|B
# orionos_recovery_slot=A|B
# orionos_recovery_snapshot=<snapshot-name>
```

### Boot Flow

```
Boot
  ↓
GRUB
  ↓
Check recovery marker
  ↓
Yes → Boot recovery snapshot
  ↓
No → Read slot (A or B)
  ↓
Mount root subvolume
  ↓
Verify integrity
  ↓
Boot successful?
  ↓
Yes → Mark slot good, continue boot
  ↓
No → Switch to other slot, reboot
```

## Update Process

### 1. Check Phase

```bash
# Check for available updates
orionos-cli update --check

# What happens:
# 1. Update pacman database
# 2. Check for upgradable packages
# 3. Compare with local cache
# 4. Notify user if updates available
```

### 2. Download Phase

```bash
# Download updates
orionos-cli update --download

# What happens:
# 1. Download packages to /var/cache/orionos/updates/
# 2. Verify package signatures
# 3. Calculate checksums
# 4. Store metadata
```

### 3. Snapshot Phase

```bash
# Create pre-update snapshot
btrfs subvolume snapshot / /.snapshots/pre-update-20240101-120000

# Snapshots are automatically cleaned up:
# - Keep last 10 snapshots
# - Keep weekly snapshots for 1 month
# - Keep monthly snapshots for 6 months
```

### 4. Apply Phase

```bash
# Apply updates
orionos-cli update --apply

# What happens:
# 1. Create pre-update snapshot
# 2. Mount inactive slot
# 3. Install packages to inactive slot
# 4. Update bootloader configuration
# 5. Switch active slot
# 6. Schedule reboot
```

### 5. Verification Phase

After booting to new slot:

```bash
# System verifies:
# - Boot success (systemd boot-complete.target)
# - Critical services running
# - Filesystem integrity
# - Network connectivity

# If verification fails:
# - Automatic rollback triggered
# - Previous slot restored
# - Admin notified
```

## Recovery

### Automatic Rollback

Triggered when:
- Boot fails 3 times in a row
- Critical services fail to start
- Filesystem corruption detected
- Manual rollback requested

```bash
# Automatic rollback process:
# 1. Detect boot failure
# 2. Read recovery snapshot from GRUB env
# 3. Boot from recovery snapshot
# 4. Mark failed slot as bad
# 5. Notify user
```

### Manual Rollback

```bash
# Rollback to specific snapshot
orionos-cli update --rollback

# Or from recovery mode:
# 1. Boot to recovery snapshot from GRUB menu
# 2. System is read-only
# 3. Choose: restore snapshot or boot previous slot
```

### Recovery Environment

Access via GRUB menu:
- "OrionOS Recovery" boot option
- Read-only root filesystem
- Network support
- Snapshot management tools
- Rollback capability

## Update Policy

### Automatic Updates

```ini
# /etc/orionos/services/update.conf
[update]
auto_check=true
auto_download=true
auto_apply=false  # Require user confirmation
schedule=daily
random_delay=3600  # 1 hour random delay
```

### Update Channels

| Channel | Stability | Update Frequency |
|---------|-----------|-----------------|
| stable | Production | Monthly |
| testing | Pre-release | Weekly |
| nightly | Development | Daily |

### Package Sources

```
# Priority order:
1. orionos (custom packages)
2. core (Arch core)
3. extra (Arch extra)
4. community (Arch community)
5. multilib (32-bit libraries)
```

## Implementation

### Update Service

```python
class UpdateService:
    def __init__(self):
        self.current_slot = self._get_current_slot()
        self.snapshots = Path("/.snapshots")
        self.update_dir = Path("/var/cache/orionos/updates")

    def check_updates(self):
        """Check for available updates"""
        subprocess.run(['pacman', '-Sy'])
        result = subprocess.run(
            ['pacman', '-Qu'],
            capture_output=True, text=True
        )
        return result.stdout.strip().split('\n')

    def create_snapshot(self, name):
        """Create Btrfs snapshot"""
        subprocess.run([
            'btrfs', 'subvolume', 'snapshot',
            '/', f'/.snapshots/{name}'
        ])

    def apply_updates(self):
        """Apply updates atomically"""
        # 1. Create snapshot
        self.create_snapshot(f"pre-update-{datetime.now()}")

        # 2. Download updates
        self.download_updates()

        # 3. Verify packages
        self.verify_updates()

        # 4. Apply to inactive slot
        other_slot = self._get_other_slot()
        self._switch_slot(other_slot)

        # 5. Schedule reboot
        subprocess.run(['systemctl', 'reboot'])
```

### GRUB Integration

```bash
# /etc/grub.d/40_orionos
menuentry "OrionOS" {
    load_video
    set gfxpayload=keep
    insmod gzio
    insmod part_gpt
    insmod btrfs

    # Read slot from environment
    if [ -z "$orionos_slot" ]; then
        set orionos_slot=A
    fi

    # Set root based on slot
    if [ "$orionos_slot" = "A" ]; then
        linux /vmlinuz-linux-orionos root=LABEL=ORIONOS_ROOT rw
    else
        linux /vmlinuz-linux-orionos root=LABEL=ORIONOS_ROOT_B rw
    fi

    initrd /initramfs-linux-orionos.img
}

menuentry "OrionOS Recovery" {
    # Boot from recovery snapshot
    linux /vmlinuz-linux-orionos root=LABEL=ORIONOS_ROOT rw \
        orionos.recovery=1 \
        orionos.snapshot=$orionos_recovery_snapshot
}
```

## Snapshots

### Automatic Snapshots

Created automatically:
- Before each update
- Weekly (if system stable)
- On user request

### Snapshot Management

```bash
# List snapshots
orionos-cli snapshot --list

# Create snapshot
orionos-cli snapshot --create backup-before-change

# Delete snapshot
orionos-cli snapshot --delete old-snapshot

# Restore snapshot
orionos-cli snapshot --rollback backup-before-change
```

### Retention Policy

```
Pre-update snapshots: Keep last 10
Weekly snapshots: Keep 4
Monthly snapshots: Keep 6
User snapshots: Keep all (manual cleanup)
```

## Integrity Verification

### Package Verification

```bash
# Verify all installed packages
pacman -Qk

# Verify package signatures
pacman -Qkk
```

### Filesystem Verification

```bash
# Btrfs scrub
btrfs scrub start /

# Check status
btrfs scrub status /
```

### Boot Verification

```bash
# Check boot success marker
systemctl is-active boot-complete.target

# View boot log
journalctl -b
```

## Troubleshooting

### Failed Update

```bash
# Check what happened
journalctl -u orionos-update

# Manual rollback
orionos-cli update --rollback

# Boot to recovery
# Select "OrionOS Recovery" in GRUB menu
```

### Disk Space

```bash
# Check snapshot disk usage
btrfs filesystem du /.snapshots

# Clean old snapshots
orionos-cli snapshot --cleanup
```

### Network Issues

```bash
# Test connectivity
ping -c 3 repo.orionos.org

# Check DNS
systemd-resolve repo.orionos.org
```

## Future Enhancements

- [ ] Delta updates (download only changes)
- [ ] Background updates (apply while running)
- [ ] Update staging (preview changes)
- [ ] Peer-to-peer updates (LAN sharing)
- [ ] Signed update metadata
- [ ] Update rollback timer (auto-revert if not confirmed)
