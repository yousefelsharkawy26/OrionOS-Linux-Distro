#!/bin/bash
# OrionOS live user setup
# Creates default live user for the ISO environment

set -euo pipefail

# Create live user
useradd -m -G wheel,video,audio,storage,optical -s /bin/bash orion 2>/dev/null || true
echo "orion:orion" | chpasswd

# Enable autologin on TTY1
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << 'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin orion --noclear %I $TERM
EOF

# Create systemd user instance for live user
mkdir -p /var/lib/AccountsService/users
cat > /var/lib/AccountsService/users/orion << EOF
[User]
LoggingIn=false
SystemAccount=false
IconFile=/var/lib/AccountsService/icons-cache/orion
Locale=
Session=
XSession=
EOF

# Allow wheel group to sudo without password
echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

# Create welcome script
cat > /usr/local/bin/orionos-welcome << 'WELCOME'
#!/bin/bash
# OrionOS Welcome Screen

clear
echo -e "\033[38;2;180;190;254m"
cat << 'LOGO'
    ___  ____  _____ _   _ ______   __
   / _ \|  _ \| ____| \ | | __ \ \ / /
  | | | | |_) |  _| |  \| |  _ \\ V /
  | |_| |  __/| |___| |\  | |_) || |
   \___/|_|   |_____|_| \_|____/ |_|

LOGO
echo -e "\033[0m"
echo "  Welcome to OrionOS Live Environment"
echo "  ===================================="
echo ""
echo "  Quick Start:"
echo "    • Launch Installer  : Open Calamares to install OrionOS"
echo "    • Try Desktop       : Explore the Hyprland desktop"
echo "    • Terminal           : Press Super+Enter for terminal"
echo ""
echo "  Keyboard Shortcuts (Hyprland):"
echo "    Super+Enter    - Terminal (Kitty)"
echo "    Super+D        - App Launcher (Wofi)"
echo "    Super+Q        - Close Window"
echo "    Super+Shift+Q  - Exit Session"
echo ""
echo "  To install OrionOS, run:"
echo "    sudo calamares"
echo ""
WELCOME
chmod +x /usr/local/bin/orionos-welcome

# Auto-start welcome on login for orion user
mkdir -p /home/orion/.config/fish
cat >> /home/orion/.bash_profile << 'EOF'

# Show welcome message on interactive login
if [[ $- == *i* ]] && [[ -z "$ORIONOS_WELCOME_SHOWN" ]]; then
    export ORIONOS_WELCOME_SHOWN=1
    /usr/local/bin/orionos-welcome
fi
EOF

chown -R orion:orion /home/orion/.config
