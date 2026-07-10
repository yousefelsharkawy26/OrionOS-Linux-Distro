# OrionOS Plugin Marketplace

## Overview
Discover, install, update, and manage plugins that extend OrionOS functionality.

## Features
- **Browse & Search**: Search plugins by name, category, or tags
- **One-Click Install**: Install plugins from the marketplace
- **Auto-Updates**: Automatic plugin updates
- **Signature Verification**: Cryptographic verification of plugins
- **Category System**: Organized plugin categories
- **Enable/Disable**: Toggle plugins without uninstalling

## CLI Usage

### Search Plugins
```bash
orionos-plugin-manager search "terminal"
orionos-plugin-manager search --category productivity
orionos-plugin-manager categories
```

### Install Plugin
```bash
orionos-plugin-manager install <plugin-id>
```

### List Installed
```bash
orionos-plugin-manager list
```

### Update
```bash
# Update specific plugin
orionos-plugin-manager update <plugin-id>

# Update all plugins
orionos-plugin-manager update
```

### Enable/Disable
```bash
orionos-plugin-manager enable <plugin-id>
orionos-plugin-manager disable <plugin-id>
```

### Uninstall
```bash
orionos-plugin-manager uninstall <plugin-id>
```

## Categories
- **Productivity**: Office tools, note-taking, task management
- **Development**: IDEs, compilers, debuggers
- **Multimedia**: Audio/video editors, players
- **System**: System utilities, monitors
- **Security**: Firewalls, antivirus, encryption
- **Networking**: Network tools, VPNs
- **Gaming**: Game launchers, overlays
- **Accessibility**: Screen readers, input helpers
- **Themes**: Visual themes and customization
- **Widgets**: Desktop widgets and panels
- **AI**: AI-powered tools and assistants
- **Automation**: Task automation and scripting

## Plugin Structure
```
plugin-id/
├── plugin.json       # Plugin metadata
├── README.md         # Documentation
├── icon.png          # Plugin icon
├── install.sh        # Post-install script
├── uninstall.sh      # Pre-uninstall script
└── src/              # Plugin source code
```

## Configuration
```json
{
    "marketplace_url": "https://marketplace.orionos.org/api/v1",
    "auto_update": true,
    "verify_signatures": true,
    "trusted_authors": ["orionos-team"],
    "max_cache_size_mb": 500
}
```

## Developing Plugins

### plugin.json Schema
```json
{
    "id": "my-plugin",
    "name": "My Plugin",
    "version": "1.0.0",
    "description": "Plugin description",
    "author": "Author Name",
    "category": "productivity",
    "license": "GPL3",
    "min_os_version": "1.0.0",
    "dependencies": []
}
```

### Publishing
1. Create plugin directory with `plugin.json`
2. Test locally with `orionos-plugin-manager install ./my-plugin`
3. Submit to marketplace via web interface
