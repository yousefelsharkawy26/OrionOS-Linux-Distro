# OrionOS Security Model

## Overview

OrionOS implements a defense-in-depth security architecture that combines multiple security layers to protect the system without compromising usability. The security model is designed to be transparent to users while providing enterprise-grade protection.

## Security Principles

1. **Secure by Default**: All security features are enabled by default
2. **Defense in Depth**: Multiple overlapping security layers
3. **Least Privilege**: Applications run with minimum required permissions
4. **User Transparency**: Security should not impede normal usage
5. **Verified Boot**: Ensure system integrity from boot
6. **Privacy First**: Local-first AI, minimal data collection

## Security Layers

```
┌─────────────────────────────────────────────────────────────┐
│  LAYER 7: Application Security                              │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐        │
│  │  AppArmor    │ │  Firejail    │ │  Bubblewrap  │        │
│  │  Profiles    │ │  Sandboxing  │ │  Containers  │        │
│  └──────────────┘ └──────────────┘ └──────────────┘        │
├─────────────────────────────────────────────────────────────┤
│  LAYER 6: Access Control                                    │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐        │
│  │  SELinux     │ │  Polkit      │ │  Sudo Rules  │        │
│  │  MAC         │ │  Privilege   │ │  Access Ctrl │        │
│  └──────────────┘ └──────────────┘ └──────────────┘        │
├─────────────────────────────────────────────────────────────┤
│  LAYER 5: Network Security                                  │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐        │
│  │  firewalld   │ │  nftables    │ │  WireGuard   │        │
│  │  Zones       │ │  Filtering   │ │  VPN         │        │
│  └──────────────┘ └──────────────┘ └──────────────┘        │
├─────────────────────────────────────────────────────────────┤
│  LAYER 4: Filesystem Security                               │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐        │
│  │  LUKS        │ │  Btrfs       │ │  IMA/EVM     │        │
│  │  Encryption  │ │  Checksums   │ │  Integrity   │        │
│  └──────────────┘ └──────────────┘ └──────────────┘        │
├─────────────────────────────────────────────────────────────┤
│  LAYER 3: Kernel Security                                   │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐        │
│  │  seccomp     │ │  namespaces  │ │  LSM         │        │
│  │  Filters     │ │  Isolation   │ │  Hooks       │        │
│  └──────────────┘ └──────────────┘ └──────────────┘        │
├─────────────────────────────────────────────────────────────┤
│  LAYER 2: Boot Security                                     │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐        │
│  │  Secure Boot │ │  TPM 2.0     │ │  Measured    │        │
│  │  Verification│ │  Key Storage │ │  Boot        │        │
│  └──────────────┘ └──────────────┘ └──────────────┘        │
├─────────────────────────────────────────────────────────────┤
│  LAYER 1: Hardware Security                                 │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐        │
│  │  CPU         │ │  TPM         │ │  UEFI        │        │
│  │  Features    │ │  Functions   │ │  Settings    │        │
│  └──────────────┘ └──────────────┘ └──────────────┘        │
└─────────────────────────────────────────────────────────────┘
```

## Layer 1: Hardware Security

### CPU Security Features

OrionOS enables all available CPU security features:

```
Intel:
- SMAP (Supervisor Mode Access Prevention)
- SMEP (Supervisor Mode Execution Prevention)
- UMIP (User Mode Instruction Prevention)
- CET (Control-flow Enforcement Technology)
- TME (Total Memory Encryption)

AMD:
- SMAP/SMEP
- SME (Secure Memory Encryption)
- SEV (Secure Encrypted Virtualization)

ARM:
- PAN (Privileged Access Never)
- UAO (User Access Override)
- BTI (Branch Target Identification)
- MTE (Memory Tagging Extension)
```

### UEFI Secure Boot

OrionOS supports custom Secure Boot key enrollment:

```bash
# Generate keys
sudo /usr/share/orionos/security/secure-boot-setup.sh

# Enroll keys
sudo efi-updatevar -f /etc/orionos/secure-boot/PK.auth PK
sudo efi-updatevar -f /etc/orionos/secure-boot/KEK.auth KEK
sudo efi-updatevar -f /etc/orionos/secure-boot/db.auth db
```

### TPM 2.0

The TPM provides hardware-backed security:

- **Key Storage**: LUKS encryption keys sealed in TPM
- **Measured Boot**: Boot chain integrity verification
- **Attestation**: Remote system attestation
- **RNG**: Hardware random number generation

## Layer 2: Boot Security

### Measured Boot Process

```
UEFI Firmware (PCR 0)
    ↓
Bootloader (PCR 4, 8, 9)
    ↓
Kernel (PCR 10)
    ↓
Initramfs (PCR 9)
    ↓
System State (PCR 11-14)
```

### LUKS + TPM Integration

```bash
# Setup TPM-bound encryption
clevis luks bind -d /dev/nvme0n1p2 tpm2 '{"pcr_ids":"0,1,2,3,4,5,6,7"}'

# Verify binding
clevis luks list -d /dev/nvme0n1p2
```

## Layer 3: Kernel Security

### Security Subsystems

| Feature | Status | Purpose |
|---------|--------|---------|
| seccomp-bpf | Enabled | System call filtering |
| Namespaces | Enabled | Process isolation |
| cgroups v2 | Enabled | Resource control |
| AppArmor | Enabled | Mandatory Access Control |
| SELinux | Enabled | Mandatory Access Control |
| YAMA | Enabled | ptrace restrictions |

### Kernel Hardening

```bash
# OrionOS kernel security settings
kernel.kptr_restrict = 2           # Hide kernel pointers
kernel.dmesg_restrict = 1          # Restrict dmesg access
kernel.yama.ptrace_scope = 1       # Restrict ptrace
kernel.unprivileged_bpf_disabled = 1  # Disable unprivileged BPF
net.core.bpf_jit_harden = 2        # Harden BPF JIT
```

## Layer 4: Filesystem Security

### LUKS Full Disk Encryption

- Default encryption for all installations
- AES-256-XTS cipher
- SHA-256 for key derivation
- TPM-bound keys for automatic unlock

### Btrfs Integrity

- CRC32C checksums for all data and metadata
- Automatic corruption detection
- Self-healing with RAID1/10
- Snapshot-based recovery

### IMA/EVM

Integrity Measurement Architecture:

```bash
# Enable IMA
ima_policy=tcb

# Verify file integrity
evmctl verify /path/to/file
```

## Layer 5: Network Security

### Firewall Zones

| Zone | Trust Level | Allowed Services |
|------|------------|-------------------|
| orionos | Default | DHCP, mDNS, SSH |
| orionos-home | High | All local services |
| orionos-public | Low | Essential only |

### Network Hardening

```bash
# TCP security
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_rfc1337 = 1

# ICMP handling
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0

# Martian logging
net.ipv4.conf.all.log_martians = 1
```

### VPN Integration

- WireGuard: Modern, fast VPN protocol
- OpenVPN: Traditional VPN support
- systemd-networkd: Native VPN management

## Layer 6: Access Control

### SELinux Policies

Targeted policy with OrionOS-specific modules:

```
orionos_t              # Main OrionOS domain
orionos_exec_t         # OrionOS executables
orionos_var_lib_t      # OrionOS data
orionos_var_log_t      # OrionOS logs
```

### Polkit Rules

OrionOS services have custom Polkit rules:

```javascript
// Allow wheel group to manage OrionOS services
polkit.addRule(function(action, subject) {
    if (subject.isInGroup("wheel")) {
        if (action.id.startsWith("org.orionos.")) {
            return polkit.Result.YES;
        }
    }
});
```

### Sudo Configuration

```bash
# Wheel group with password
%wheel ALL=(ALL) ALL

# OrionOS specific commands NOPASSWD
%wheel ALL=(ALL) NOPASSWD: /usr/bin/orionos-cli
```

## Layer 7: Application Security

### AppArmor Profiles

OrionOS includes profiles for:

| Application | Profile | Restrictions |
|-------------|---------|-------------|
| Desktop | orionos-desktop | Filesystem, network |
| AI Service | orionos-ai | GPU access, models dir |
| Gaming | orionos-gaming | Game directories, GPU |

### Sandboxed Applications

Flatpak applications run in sandboxed environments:

```bash
# Install sandboxed application
flatpak install flathub com.example.App

# View permissions
flatpak info --show-permissions com.example.App

# Override permissions
flatpak override --filesystem=home com.example.App
```

### Permission System

OrionOS implements a permission system for native applications:

```ini
# /etc/orionos/security/permissions.conf
[firefox]
network=true
camera=ask
microphone=ask
location=ask
filesystem=xdg-download;xdg-documents
```

## USB Security

### USBGuard

USBGuard controls USB device access:

```bash
# List connected devices
usbguard list-devices

# Allow device
usbguard allow-device <id>

# Block device
usbguard block-device <id>
```

Default policy:
- USB hubs: Allow
- HID devices (keyboard/mouse): Allow
- Storage devices: Allow (with authorization)
- Unknown devices: Block

## Audit System

### Audit Rules

OrionOS enables comprehensive auditing:

```bash
# Monitor authentication
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity

# Monitor sudo
-w /etc/sudoers -p wa -k sudoers

# Monitor kernel modules
-a always,exit -F arch=b64 -S init_module -S delete_module -k modules
```

### Audit Viewer

```bash
# View recent audit events
ausearch -ts recent

# View failed authentication
ausearch -m USER_AUTH -sv no

# Generate report
aureport --login --summary
```

## Vulnerability Management

### Automatic Updates

```bash
# Check for security updates
orionos-cli update --check

# Apply security updates
orionos-cli update --apply

# Rollback if issues
orionos-cli update --rollback
```

### Security Scanning

```bash
# Run security scan
lynis audit system

# Check for known vulnerabilities
arch-audit
```

## Security Checklist

### Installation

- [ ] Enable Secure Boot
- [ ] Enable TPM + LUKS encryption
- [ ] Set strong password
- [ ] Enable firewall
- [ ] Configure automatic updates

### Daily Use

- [ ] Keep system updated
- [ ] Use AppArmor profiles
- [ ] Verify USB devices before allowing
- [ ] Monitor audit logs
- [ ] Use VPN on public networks

### Development

- [ ] Follow secure coding practices
- [ ] Test security features
- [ ] Review Polkit rules
- [ ] Validate AppArmor profiles
- [ ] Document security implications

## Incident Response

### Compromised System

1. **Isolate**: Disconnect from network
2. **Assess**: Check audit logs
3. **Recover**: Restore from clean snapshot
4. **Analyze**: Determine attack vector
5. **Harden**: Apply additional security measures

### Reporting

Report security vulnerabilities to:
- Email: security@orionos.org
- GPG: [security team key]
- Response time: 48 hours acknowledgment
