# OrionOS Secure Boot

## Overview
Full UEFI Secure Boot support with custom key enrollment, kernel signing, and TPM integration.

## Features
- **Custom Key Enrollment**: Generate and enroll PK, KEK, db, dbx keys
- **Kernel Signing**: Automatic kernel image signing with sbsigntools
- **MOK Support**: Machine Owner Key enrollment for third-party modules
- **TPM Integration**: Seal keys to TPM for hardware-backed security
- **Auto-sign on Update**: Automatically sign kernels after updates
- **Verification**: Verify signed boot chain integrity

## Usage

### Initial Setup
```bash
# Generate keys and set up Secure Boot
sudo orionos-secureboot-setup setup

# Enroll keys in UEFI firmware
sudo orionos-secureboot-setup enroll

# Sign all installed kernels
sudo orionos-secureboot-setup sign-all

# Verify Secure Boot status
sudo orionos-secureboot-setup verify
```

### Sign Individual Kernel
```bash
sudo orionos-secureboot-setup sign-kernel /boot/vmlinuz-linux
```

### Check Status
```bash
orionos-secureboot-verify
```

## Key Structure
```
/var/lib/orionos/secureboot/keys/
├── PK/    # Platform Key
│   ├── PK.key
│   ├── PK.crt
│   └── PK.der
├── KEK/   # Key Exchange Key
│   ├── KEK.key
│   ├── KEK.crt
│   └── KEK.der
├── db/    # Signature Database
│   ├── db.key
│   ├── db.crt
│   └── db.der
└── dbx/   # Signature Blacklist
    ├── dbx.key
    ├── dbx.crt
    └── dbx.der
```

## Configuration
```json
{
    "key_dir": "/var/lib/orionos/secureboot/keys",
    "auto_sign_kernels": true,
    "sign_after_update": true,
    "tpm_seal_keys": true,
    "mok_enrollment": true
}
```

## Troubleshooting

### Secure Boot Blocks Boot
1. Boot with Secure Boot disabled
2. Re-enroll keys: `sudo orionos-secureboot-setup enroll`
3. Re-sign kernels: `sudo orionos-secureboot-setup sign-all`

### MOK Enrollment Failed
```bash
# List pending MOK enrollments
mokutil --list-enrolled

# Import MOK certificate
sudo mokutil --import /var/lib/orionos/secureboot/mok/MOK.crt
# Reboot and enroll via MokManager
```
