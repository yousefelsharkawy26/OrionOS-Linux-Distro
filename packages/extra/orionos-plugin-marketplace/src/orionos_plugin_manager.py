#!/usr/bin/env python3
"""
OrionOS Plugin Marketplace
Discover, install, update, and manage plugins for OrionOS.
"""

import os
import sys
import json
import yaml
import shutil
import logging
import hashlib
import argparse
import tempfile
import subprocess
from pathlib import Path
from typing import Optional, Dict, List
from dataclasses import dataclass, asdict
from datetime import datetime

import requests

CONFIG_DIR = Path("/etc/orionos")
PLUGIN_DIR = Path("/usr/lib/orionos/plugins")
CACHE_DIR = Path("/var/cache/orionos/plugin-marketplace")
DATA_DIR = Path("/var/lib/orionos/plugin-marketplace")
LOG_DIR = Path("/var/log/orionos")

LOG_DIR.mkdir(parents=True, exist_ok=True)
PLUGIN_DIR.mkdir(parents=True, exist_ok=True)
CACHE_DIR.mkdir(parents=True, exist_ok=True)
DATA_DIR.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.FileHandler(LOG_DIR / "plugin-marketplace.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("orionos-plugin-marketplace")


@dataclass
class Plugin:
    id: str
    name: str
    version: str
    description: str
    author: str
    category: str
    icon: str
    screenshots: List[str]
    license: str
    homepage: str
    repository: str
    downloads: int
    rating: float
    verified: bool
    tags: List[str]
    min_os_version: str
    dependencies: List[str]
    install_size: int
    last_updated: str


@dataclass
class InstalledPlugin:
    plugin_id: str
    version: str
    installed_at: str
    enabled: bool
    settings: Dict[str, any]


@dataclass
class PluginConfig:
    marketplace_url: str = "https://marketplace.orionos.org/api/v1"
    auto_update: bool = True
    auto_update_interval_hours: int = 24
    verify_signatures: bool = True
    trusted_authors: List[str] = None
    blocked_plugins: List[str] = None
    plugin_dir: str = str(PLUGIN_DIR)
    cache_dir: str = str(CACHE_DIR)
    max_cache_size_mb: int = 500

    def __post_init__(self):
        if self.trusted_authors is None:
            self.trusted_authors = ["orionos-team", "verified-contributors"]
        if self.blocked_plugins is None:
            self.blocked_plugins = []


class PluginMarketplace:
    """Plugin marketplace client"""
    
    def __init__(self, config: PluginConfig):
        self.config = config
        self.installed_file = DATA_DIR / "installed.json"
        self.installed: Dict[str, InstalledPlugin] = {}
        self._load_installed()

    def _load_installed(self):
        if self.installed_file.exists():
            with open(self.installed_file) as f:
                data = json.load(f)
                for pid, pdata in data.items():
                    self.installed[pid] = InstalledPlugin(**pdata)

    def _save_installed(self):
        with open(self.installed_file, 'w') as f:
            json.dump({pid: asdict(p) for pid, p in self.installed.items()}, f, indent=2)

    def search(self, query: str = "", category: str = "", page: int = 1, per_page: int = 20) -> List[Plugin]:
        """Search marketplace for plugins"""
        params = {"page": page, "per_page": per_page}
        if query:
            params["q"] = query
        if category:
            params["category"] = category

        try:
            response = requests.get(f"{self.config.marketplace_url}/plugins", params=params, timeout=10)
            response.raise_for_status()
            data = response.json()
            return [Plugin(**p) for p in data.get("plugins", [])]
        except requests.RequestException as e:
            logger.error(f"Marketplace search failed: {e}")
            return []

    def get_plugin(self, plugin_id: str) -> Optional[Plugin]:
        """Get plugin details"""
        try:
            response = requests.get(f"{self.config.marketplace_url}/plugins/{plugin_id}", timeout=10)
            response.raise_for_status()
            return Plugin(**response.json())
        except requests.RequestException as e:
            logger.error(f"Failed to get plugin {plugin_id}: {e}")
            return None

    def install(self, plugin_id: str) -> bool:
        """Install a plugin"""
        if plugin_id in self.installed:
            logger.info(f"Plugin {plugin_id} already installed")
            return True

        plugin = self.get_plugin(plugin_id)
        if not plugin:
            return False

        if plugin_id in self.config.blocked_plugins:
            logger.error(f"Plugin {plugin_id} is blocked")
            return False

        logger.info(f"Installing plugin: {plugin.name} v{plugin.version}")

        try:
            download_url = f"{self.config.marketplace_url}/plugins/{plugin_id}/download"
            response = requests.get(download_url, timeout=30)
            response.raise_for_status()

            with tempfile.TemporaryDirectory() as tmpdir:
                plugin_file = Path(tmpdir) / f"{plugin_id}.tar.gz"
                plugin_file.write_bytes(response.content)

                if self.config.verify_signatures:
                    if not self._verify_signature(plugin_file, plugin_id):
                        logger.error(f"Signature verification failed for {plugin_id}")
                        return False

                plugin_path = Path(self.config.plugin_dir) / plugin_id
                plugin_path.mkdir(parents=True, exist_ok=True)

                subprocess.run([
                    "tar", "xzf", str(plugin_file), "-C", str(plugin_path)
                ], check=True)

                metadata_file = plugin_path / "plugin.json"
                if not metadata_file.exists():
                    metadata_file.write_text(json.dumps(asdict(plugin), indent=2))

                self.installed[plugin_id] = InstalledPlugin(
                    plugin_id=plugin_id,
                    version=plugin.version,
                    installed_at=datetime.now().isoformat(),
                    enabled=True,
                    settings={}
                )
                self._save_installed()

                logger.info(f"Plugin {plugin.name} installed successfully")
                return True

        except Exception as e:
            logger.error(f"Failed to install {plugin_id}: {e}")
            return False

    def uninstall(self, plugin_id: str) -> bool:
        """Uninstall a plugin"""
        if plugin_id not in self.installed:
            logger.info(f"Plugin {plugin_id} not installed")
            return True

        logger.info(f"Uninstalling plugin: {plugin_id}")

        plugin_path = Path(self.config.plugin_dir) / plugin_id
        if plugin_path.exists():
            shutil.rmtree(plugin_path)

        del self.installed[plugin_id]
        self._save_installed()

        logger.info(f"Plugin {plugin_id} uninstalled")
        return True

    def update(self, plugin_id: str) -> bool:
        """Update a plugin"""
        if plugin_id not in self.installed:
            logger.error(f"Plugin {plugin_id} not installed")
            return False

        plugin = self.get_plugin(plugin_id)
        if not plugin:
            return False

        current = self.installed[plugin_id]
        if current.version == plugin.version:
            logger.info(f"Plugin {plugin_id} is up to date")
            return True

        logger.info(f"Updating {plugin_id} from {current.version} to {plugin.version}")
        self.uninstall(plugin_id)
        return self.install(plugin_id)

    def update_all(self) -> Dict[str, bool]:
        """Update all installed plugins"""
        results = {}
        for plugin_id in list(self.installed.keys()):
            results[plugin_id] = self.update(plugin_id)
        return results

    def list_installed(self) -> List[InstalledPlugin]:
        """List all installed plugins"""
        return list(self.installed.values())

    def enable(self, plugin_id: str) -> bool:
        """Enable a plugin"""
        if plugin_id not in self.installed:
            return False
        self.installed[plugin_id].enabled = True
        self._save_installed()
        return True

    def disable(self, plugin_id: str) -> bool:
        """Disable a plugin"""
        if plugin_id not in self.installed:
            return False
        self.installed[plugin_id].enabled = False
        self._save_installed()
        return True

    def get_categories(self) -> List[str]:
        """Get available plugin categories"""
        return [
            "productivity", "development", "multimedia", "system",
            "security", "networking", "gaming", "accessibility",
            "themes", "widgets", "ai", "automation"
        ]

    def _verify_signature(self, plugin_file: Path, plugin_id: str) -> bool:
        """Verify plugin signature"""
        try:
            sig_file = plugin_file.with_suffix('.sig')
            if not sig_file.exists():
                if self.config.trusted_authors:
                    return True
                return False

            result = subprocess.run([
                "gpg", "--verify", str(sig_file), str(plugin_file)
            ], capture_output=True)
            return result.returncode == 0
        except Exception:
            return False


def load_config() -> PluginConfig:
    config_file = CONFIG_DIR / "plugin-marketplace.conf"
    if config_file.exists():
        try:
            with open(config_file) as f:
                return PluginConfig(**json.load(f))
        except (json.JSONDecodeError, TypeError):
            pass
    return PluginConfig()


def main():
    parser = argparse.ArgumentParser(description="OrionOS Plugin Marketplace")
    subparsers = parser.add_subparsers(dest="command", help="Command to execute")

    search_parser = subparsers.add_parser("search", help="Search for plugins")
    search_parser.add_argument("query", nargs="?", default="", help="Search query")
    search_parser.add_argument("--category", help="Filter by category")
    search_parser.add_argument("--page", type=int, default=1)
    search_parser.add_argument("--per-page", type=int, default=20)

    install_parser = subparsers.add_parser("install", help="Install a plugin")
    install_parser.add_argument("plugin_id", help="Plugin ID to install")

    uninstall_parser = subparsers.add_parser("uninstall", help="Uninstall a plugin")
    uninstall_parser.add_argument("plugin_id", help="Plugin ID to uninstall")

    update_parser = subparsers.add_parser("update", help="Update plugins")
    update_parser.add_argument("plugin_id", nargs="?", help="Plugin ID (omit for all)")

    subparsers.add_parser("list", help="List installed plugins")
    subparsers.add_parser("categories", help="List categories")

    enable_parser = subparsers.add_parser("enable", help="Enable a plugin")
    enable_parser.add_argument("plugin_id", help="Plugin ID to enable")

    disable_parser = subparsers.add_parser("disable", help="Disable a plugin")
    disable_parser.add_argument("plugin_id", help="Plugin ID to disable")

    args = parser.parse_args()
    config = load_config()
    marketplace = PluginMarketplace(config)

    if args.command == "search":
        plugins = marketplace.search(args.query, args.category or "", args.page, args.per_page)
        if not plugins:
            print("No plugins found")
            return
        for p in plugins:
            verified = " [Verified]" if p.verified else ""
            installed = " [Installed]" if p.id in marketplace.installed else ""
            print(f"  {p.id}: {p.name} v{p.version}{verified}{installed}")
            print(f"    {p.description}")
            print(f"    Downloads: {p.downloads} | Rating: {p.rating}/5 | Category: {p.category}")
            print()

    elif args.command == "install":
        marketplace.install(args.plugin_id)

    elif args.command == "uninstall":
        marketplace.uninstall(args.plugin_id)

    elif args.command == "update":
        if args.plugin_id:
            marketplace.update(args.plugin_id)
        else:
            results = marketplace.update_all()
            for pid, success in results.items():
                status = "OK" if success else "FAILED"
                print(f"  {pid}: {status}")

    elif args.command == "list":
        plugins = marketplace.list_installed()
        if not plugins:
            print("No plugins installed")
            return
        for p in plugins:
            status = "enabled" if p.enabled else "disabled"
            print(f"  {p.plugin_id} v{p.version} [{status}] (installed: {p.installed_at})")

    elif args.command == "categories":
        for cat in marketplace.get_categories():
            print(f"  - {cat}")

    elif args.command == "enable":
        marketplace.enable(args.plugin_id)

    elif args.command == "disable":
        marketplace.disable(args.plugin_id)

    else:
        parser.print_help()


if __name__ == "__main__":
    main()
