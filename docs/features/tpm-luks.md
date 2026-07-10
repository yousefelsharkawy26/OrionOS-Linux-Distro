# OrionOS TPM + LUKS

## Overview
Hardware-backed full disk encryption using TPM 2.0 and LUKS2. Enables automatic disk unlock without passphrase on trusted hardware.

## Features
- **TPM2 Auto-unlock**: Disk unlocks automatically using TPM-bound keys
- **PCR Policy**: Seal keys to platform configuration registers
- **PIN Fallback**: Optional PIN for additional security
- **Header Backup**: Automatic LUKS header backup before changes
- **Emergency Repair**: Recovery tools for TPM/LUKS issues
- **GRUB Integration**: Works with GRUB bootloader

## Usage

### Auto-Setup
```bash
# Detect LUKS device and enroll TPM
sudo orionos-tpm-luks-setup setup

# Check current status
sudo orionos-tpm-luks-status
```

### Manual Enrollment
```bash
# Enroll TPM for specific device
sudo orionos-tpm-luks-enroll /dev/nvme0n1p2

# Add PIN fallback
sudo orionos-tpm-luks-setup pin

# Backup LUKS headers
sudo orionos-tpm-luks-setup backup
```

### Status Check
```bash
orionos-tpm-luks-status
```

## PCR Policy
Default policy binds to PCR registers:
| PCR | Description |
|-----|-------------|
| 0   | UEFI firmware measurements |
| 1   | UEFI configuration |
| 2   | Option ROM code |
| 3   | Option ROM configuration |
| 7   | Secure Boot state |

## Recovery

### TPM Unseal Fails
1. Boot from live USB
2. Manually unlock with passphrase
3. Re-enroll TPM:
   ```bash
   sudo orionos-tpm-luks-setup enroll
   ```

### Lost Passphrase + TPM Failure
1. Use backed up LUKS headers:
   ```bash
   sudo cryptsetup luksHeaderRestore /dev/nvme0n1p2 \
       --header-backup-file /var/lib/orionos/tpm-luks/backup/nvme0n1p2_header.bak
   ```

## Security Considerations
- TPM-bound keys provide reasonable protection against offline attacks
- Physical access to TPM may still allow key extraction in some scenarios
- For maximum security, combine with strong passphrase
- Regular backup of LUKS headers is essential
