#!/usr/bin/env python3
"""
=============================================================================
OrionOS Ecosystem Services
Cross-device integration: phone sync, clipboard sync, file sharing,
universal control, cloud sync, and remote device management
=============================================================================

Services:
- PhoneSync: Sync notifications, calls, messages with mobile devices
- ClipboardSync: Cross-device clipboard sharing
- NearbyShare: AirDrop-like file sharing using local network
- CloudSync: Synchronize files with cloud storage providers
- UniversalControl: Share mouse/keyboard across devices
- RemoteManagement: Remote device management and control
"""

import argparse
import asyncio
import hashlib
import json
import logging
import os
import socket
import struct
import subprocess
import sys
import threading
import time
import uuid
from dataclasses import dataclass, asdict
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional, Set
import base64
import zlib

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger('orionos-ecosystem')


# =============================================================================
# Device Discovery and Registration
# =============================================================================

@dataclass
class Device:
    """Represents a registered device in the ecosystem"""
    id: str
    name: str
    type: str  # desktop, phone, tablet, laptop
    os: str
    ip_address: str
    capabilities: List[str]
    last_seen: float
    public_key: str = ""
    paired: bool = False


class DeviceManager:
    """Manages device discovery and pairing"""

    DISCOVERY_PORT = 36789
    DISCOVERY_INTERVAL = 30

    def __init__(self, config_dir: Path):
        self.config_dir = config_dir
        self.devices_file = config_dir / "devices.json"
        self.my_device_file = config_dir / "my-device.json"
        self.devices: Dict[str, Device] = {}
        self.my_device: Optional[Device] = None
        self._load_devices()
        self._load_my_device()

    def _load_devices(self):
        """Load registered devices from disk"""
        if self.devices_file.exists():
            data = json.loads(self.devices_file.read_text())
            for dev_id, dev_data in data.items():
                self.devices[dev_id] = Device(**dev_data)

    def _save_devices(self):
        """Save registered devices to disk"""
        data = {dev_id: asdict(dev) for dev_id, dev in self.devices.items()}
        self.devices_file.write_text(json.dumps(data, indent=2))

    def _load_my_device(self):
        """Load this device's identity"""
        if self.my_device_file.exists():
            data = json.loads(self.my_device_file.read_text())
            self.my_device = Device(**data)
        else:
            # Create new device identity
            self.my_device = Device(
                id=str(uuid.uuid4()),
                name=socket.gethostname(),
                type="desktop",
                os="OrionOS",
                ip_address=self._get_local_ip(),
                capabilities=["clipboard", "files", "notifications", "remote_control"],
                last_seen=time.time(),
            )
            self._save_my_device()

    def _save_my_device(self):
        if self.my_device:
            self.my_device_file.write_text(json.dumps(asdict(self.my_device), indent=2))

    def _get_local_ip(self) -> str:
        """Get the local IP address"""
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))
            ip = s.getsockname()[0]
            s.close()
            return ip
        except Exception:
            return "127.0.0.1"

    def discover_devices(self) -> List[Device]:
        """Discover nearby devices on the network"""
        discovered = []

        # Send discovery broadcast
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        sock.settimeout(2)

        discovery_msg = json.dumps({
            "type": "discover",
            "device": asdict(self.my_device) if self.my_device else {},
        })

        try:
            sock.sendto(discovery_msg.encode(), ("<broadcast>", self.DISCOVERY_PORT))

            # Listen for responses
            start_time = time.time()
            while time.time() - start_time < 5:
                try:
                    data, addr = sock.recvfrom(1024)
                    response = json.loads(data.decode())

                    if response.get("type") == "discover_response":
                        dev_data = response.get("device", {})
                        device = Device(**dev_data)
                        device.ip_address = addr[0]
                        device.last_seen = time.time()

                        if device.id != (self.my_device.id if self.my_device else ""):
                            discovered.append(device)
                            # Update known devices
                            self.devices[device.id] = device

                except socket.timeout:
                    break
                except Exception as e:
                    logger.debug(f"Discovery error: {e}")

        finally:
            sock.close()

        self._save_devices()
        return discovered

    def get_paired_devices(self) -> List[Device]:
        """Get all paired devices"""
        return [d for d in self.devices.values() if d.paired]

    def pair_device(self, device_id: str) -> bool:
        """Pair with a discovered device"""
        if device_id in self.devices:
            self.devices[device_id].paired = True
            self._save_devices()

            # Send pair request to device
            device = self.devices[device_id]
            self._send_pair_request(device)

            logger.info(f"Paired with device: {device.name}")
            return True
        return False

    def unpair_device(self, device_id: str) -> bool:
        """Unpair a device"""
        if device_id in self.devices:
            self.devices[device_id].paired = False
            self._save_devices()
            logger.info(f"Unpaired device: {self.devices[device_id].name}")
            return True
        return False

    def _send_pair_request(self, device: Device):
        """Send pair request to a device"""
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(5)
            sock.connect((device.ip_address, self.DISCOVERY_PORT + 1))

            pair_msg = json.dumps({
                "type": "pair_request",
                "device": asdict(self.my_device) if self.my_device else {},
            })

            sock.send(pair_msg.encode())
            sock.close()
        except Exception as e:
            logger.warning(f"Failed to send pair request: {e}")


# =============================================================================
# Clipboard Sync
# =============================================================================

class ClipboardSync:
    """Cross-device clipboard synchronization"""

    PORT = 36790
    MAX_CLIPBOARD_SIZE = 10 * 1024 * 1024  # 10MB

    def __init__(self, device_manager: DeviceManager):
        self.device_manager = device_manager
        self.last_clipboard = ""
        self._running = False
        self._server_thread = None

    def start_server(self):
        """Start clipboard sync server"""
        self._running = True
        self._server_thread = threading.Thread(target=self._server_loop, daemon=True)
        self._server_thread.start()
        logger.info("Clipboard sync server started")

    def stop_server(self):
        """Stop clipboard sync server"""
        self._running = False
        logger.info("Clipboard sync server stopped")

    def _server_loop(self):
        """Listen for incoming clipboard data from paired devices"""
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

        try:
            sock.bind(("0.0.0.0", self.PORT))
            sock.listen(5)
            sock.settimeout(1)

            while self._running:
                try:
                    conn, addr = sock.accept()
                    threading.Thread(
                        target=self._handle_clipboard_receive,
                        args=(conn, addr),
                        daemon=True
                    ).start()
                except socket.timeout:
                    continue
                except Exception as e:
                    logger.error(f"Clipboard server error: {e}")

        finally:
            sock.close()

    def _handle_clipboard_receive(self, conn: socket.socket, addr):
        """Handle incoming clipboard data"""
        try:
            data = b""
            while True:
                chunk = conn.recv(4096)
                if not chunk:
                    break
                data += chunk

            message = json.loads(data.decode())

            if message.get("type") == "clipboard":
                clipboard_data = message.get("data", "")
                content_type = message.get("content_type", "text")

                if content_type == "text":
                    # Set local clipboard
                    self._set_local_clipboard(clipboard_data)
                    logger.debug(f"Received clipboard from {addr[0]}")

        except Exception as e:
            logger.error(f"Clipboard receive error: {e}")
        finally:
            conn.close()

    def _set_local_clipboard(self, text: str):
        """Set the local Wayland clipboard"""
        try:
            # Use wl-copy for Wayland
            process = subprocess.Popen(
                ["wl-copy"],
                stdin=subprocess.PIPE,
                text=True
            )
            process.communicate(input=text)
        except FileNotFoundError:
            logger.warning("wl-copy not found, clipboard sync disabled")

    def _get_local_clipboard(self) -> str:
        """Get the local Wayland clipboard"""
        try:
            result = subprocess.run(
                ["wl-paste"],
                capture_output=True,
                text=True,
                timeout=5
            )
            return result.stdout
        except (FileNotFoundError, subprocess.TimeoutExpired):
            return ""

    def sync_clipboard(self):
        """Check for clipboard changes and sync to paired devices"""
        current = self._get_local_clipboard()

        if current != self.last_clipboard and len(current) < self.MAX_CLIPBOARD_SIZE:
            self.last_clipboard = current

            # Send to all paired devices
            for device in self.device_manager.get_paired_devices():
                self._send_clipboard(device, current)

    def _send_clipboard(self, device: Device, text: str):
        """Send clipboard data to a device"""
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(5)
            sock.connect((device.ip_address, self.PORT))

            message = json.dumps({
                "type": "clipboard",
                "data": text,
                "content_type": "text",
                "device_id": self.device_manager.my_device.id if self.device_manager.my_device else "",
            })

            sock.send(message.encode())
            sock.close()

        except Exception as e:
            logger.debug(f"Failed to send clipboard to {device.name}: {e}")

    def start_monitoring(self):
        """Start monitoring clipboard changes"""
        logger.info("Starting clipboard monitoring...")
        while self._running:
            self.sync_clipboard()
            time.sleep(1)


# =============================================================================
# Nearby Share (AirDrop-like)
# =============================================================================

class NearbyShare:
    """Local network file sharing similar to AirDrop"""

    DISCOVERY_PORT = 36791
    TRANSFER_PORT = 36792
    CHUNK_SIZE = 65536
    PROTOCOL_VERSION = "1.0"

    def __init__(self, device_manager: DeviceManager, download_dir: Path = None):
        self.device_manager = device_manager
        self.download_dir = download_dir or Path.home() / "Downloads"
        self.download_dir.mkdir(parents=True, exist_ok=True)
        self._running = False
        self._transfers: Dict[str, Dict[str, Any]] = {}

    def start_server(self):
        """Start file sharing server"""
        self._running = True
        threading.Thread(target=self._server_loop, daemon=True).start()
        logger.info("Nearby Share server started")

    def stop_server(self):
        self._running = False

    def _server_loop(self):
        """Listen for file transfer requests"""
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

        try:
            sock.bind(("0.0.0.0", self.TRANSFER_PORT))
            sock.listen(5)
            sock.settimeout(1)

            while self._running:
                try:
                    conn, addr = sock.accept()
                    threading.Thread(
                        target=self._handle_transfer,
                        args=(conn, addr),
                        daemon=True
                    ).start()
                except socket.timeout:
                    continue
        finally:
            sock.close()

    def _handle_transfer(self, conn: socket.socket, addr):
        """Handle incoming file transfer"""
        try:
            # Receive transfer metadata
            header_data = conn.recv(4096)
            header = json.loads(header_data.decode())

            if header.get("type") != "file_offer":
                return

            file_name = header.get("file_name", "unknown")
            file_size = header.get("file_size", 0)
            transfer_id = header.get("transfer_id", str(uuid.uuid4()))
            sender_name = header.get("sender_name", "Unknown")

            logger.info(f"File offer from {sender_name}: {file_name} ({file_size} bytes)")

            # Send acceptance
            accept_msg = json.dumps({
                "type": "accept",
                "transfer_id": transfer_id,
            })
            conn.send(accept_msg.encode())

            # Receive file
            output_path = self.download_dir / file_name
            received = 0

            with open(output_path, 'wb') as f:
                while received < file_size:
                    chunk = conn.recv(self.CHUNK_SIZE)
                    if not chunk:
                        break
                    f.write(chunk)
                    received += len(chunk)

            if received == file_size:
                logger.info(f"File received: {output_path}")

                # Send notification
                subprocess.run([
                    "notify-send",
                    "OrionOS Nearby Share",
                    f"Received '{file_name}' from {sender_name}",
                    "-i", "folder-download",
                    "-a", "OrionOS Ecosystem"
                ], capture_output=True)
            else:
                logger.warning(f"Incomplete transfer: {received}/{file_size}")
                output_path.unlink(missing_ok=True)

        except Exception as e:
            logger.error(f"Transfer error: {e}")
        finally:
            conn.close()

    def send_file(self, file_path: Path, target_device: Device) -> bool:
        """Send a file to a specific device"""
        if not file_path.exists():
            logger.error(f"File not found: {file_path}")
            return False

        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(30)
            sock.connect((target_device.ip_address, self.TRANSFER_PORT))

            # Send file offer
            transfer_id = str(uuid.uuid4())
            offer_msg = json.dumps({
                "type": "file_offer",
                "transfer_id": transfer_id,
                "file_name": file_path.name,
                "file_size": file_path.stat().st_size,
                "sender_name": socket.gethostname(),
                "protocol_version": self.PROTOCOL_VERSION,
            })
            sock.send(offer_msg.encode())

            # Wait for acceptance
            response_data = sock.recv(4096)
            response = json.loads(response_data.decode())

            if response.get("type") == "accept":
                # Send file data
                with open(file_path, 'rb') as f:
                    while True:
                        chunk = f.read(self.CHUNK_SIZE)
                        if not chunk:
                            break
                        sock.send(chunk)

                logger.info(f"File sent: {file_path.name} -> {target_device.name}")

                # Notification
                subprocess.run([
                    "notify-send",
                    "OrionOS Nearby Share",
                    f"Sent '{file_path.name}' to {target_device.name}",
                    "-i", "folder-upload",
                    "-a", "OrionOS Ecosystem"
                ], capture_output=True)

                return True
            else:
                logger.warning(f"Transfer rejected by {target_device.name}")
                return False

        except Exception as e:
            logger.error(f"Send error: {e}")
            return False
        finally:
            sock.close()

    def share_file(self, file_path: str):
        """Share a file to all paired devices (CLI convenience)"""
        path = Path(file_path)
        devices = self.device_manager.get_paired_devices()

        if not devices:
            logger.warning("No paired devices found")
            return

        print(f"Sharing '{path.name}' with {len(devices)} device(s)...")

        for device in devices:
            success = self.send_file(path, device)
            status = "✓" if success else "✗"
            print(f"  {status} {device.name}")


# =============================================================================
# Cloud Sync
# =============================================================================

class CloudSync:
    """Cloud storage synchronization"""

    SUPPORTED_PROVIDERS = {
        "nextcloud": {
            "name": "Nextcloud",
            "config_keys": ["server_url", "username", "password"],
        },
        "owncloud": {
            "name": "ownCloud",
            "config_keys": ["server_url", "username", "password"],
        },
        "webdav": {
            "name": "WebDAV",
            "config_keys": ["server_url", "username", "password"],
        },
        "sftp": {
            "name": "SFTP",
            "config_keys": ["host", "port", "username", "password", "key_file"],
        },
        "rsync": {
            "name": "rsync",
            "config_keys": ["host", "path", "username", "key_file"],
        },
    }

    def __init__(self, config_dir: Path):
        self.config_dir = config_dir
        self.providers_file = config_dir / "cloud-providers.json"
        self.providers: Dict[str, Dict[str, Any]] = {}
        self._load_providers()

    def _load_providers(self):
        if self.providers_file.exists():
            self.providers = json.loads(self.providers_file.read_text())

    def _save_providers(self):
        self.providers_file.write_text(json.dumps(self.providers, indent=2))

    def list_providers(self):
        """List configured cloud providers"""
        return self.providers

    def add_provider(self, name: str, provider_type: str, config: Dict[str, str]) -> bool:
        """Add a cloud provider"""
        if provider_type not in self.SUPPORTED_PROVIDERS:
            logger.error(f"Unsupported provider: {provider_type}")
            return False

        self.providers[name] = {
            "type": provider_type,
            "config": config,
            "sync_folders": [],
            "enabled": True,
            "last_sync": None,
        }
        self._save_providers()
        logger.info(f"Added provider: {name} ({provider_type})")
        return True

    def remove_provider(self, name: str):
        """Remove a cloud provider"""
        if name in self.providers:
            del self.providers[name]
            self._save_providers()

    def add_sync_folder(self, provider_name: str, local_path: str, remote_path: str):
        """Add a folder to sync"""
        if provider_name not in self.providers:
            return False

        self.providers[provider_name]["sync_folders"].append({
            "local": local_path,
            "remote": remote_path,
            "enabled": True,
        })
        self._save_providers()
        return True

    def sync(self, provider_name: str = None):
        """Sync with cloud providers"""
        providers = ([provider_name] if provider_name
                      else list(self.providers.keys()))

        for name in providers:
            if name not in self.providers:
                continue

            provider = self.providers[name]
            if not provider.get("enabled"):
                continue

            ptype = provider["type"]
            config = provider["config"]

            logger.info(f"Syncing with {name} ({ptype})...")

            for folder in provider.get("sync_folders", []):
                if not folder.get("enabled"):
                    continue

                self._sync_folder(ptype, config, folder["local"], folder["remote"])

            provider["last_sync"] = datetime.now().isoformat()

        self._save_providers()

    def _sync_folder(self, provider_type: str, config: Dict, local: str, remote: str):
        """Sync a single folder using appropriate method"""
        try:
            if provider_type in ("nextcloud", "owncloud", "webdav"):
                # Use rclone for WebDAV-based providers
                remote_name = f"{provider_type}_{hashlib.md5(config['server_url'].encode()).hexdigest()[:8]}"

                # Configure rclone remote
                subprocess.run([
                    "rclone", "config", "create",
                    remote_name, "webdav",
                    "url", config["server_url"],
                    "vendor", provider_type,
                    "user", config["username"],
                    "pass", config["password"],
                ], capture_output=True)

                # Sync
                subprocess.run([
                    "rclone", "sync",
                    local,
                    f"{remote_name}:{remote}",
                    "--progress",
                ], check=True)

            elif provider_type == "sftp":
                # Use rsync over SSH
                ssh_opts = f"-e 'ssh -p {config.get('port', 22)}"
                if config.get("key_file"):
                    ssh_opts += f" -i {config['key_file']}'"
                else:
                    ssh_opts += "'"

                subprocess.run([
                    "rsync", "-avz", "--progress",
                    *ssh_opts.split(),
                    local,
                    f"{config['username']}@{config['host']}:{remote}",
                ], check=True)

            elif provider_type == "rsync":
                subprocess.run([
                    "rsync", "-avz", "--progress",
                    "-e", f"ssh -i {config.get('key_file', '~/.ssh/id_rsa')}",
                    local,
                    f"{config['username']}@{config['host']}:{config['path']}/{remote}",
                ], check=True)

            logger.info(f"  Synced: {local} -> {remote}")

        except subprocess.CalledProcessError as e:
            logger.error(f"  Sync failed for {local}: {e}")


# =============================================================================
# Universal Control (Mouse/Keyboard Sharing)
# =============================================================================

class UniversalControl:
    """Share mouse and keyboard across devices"""

    def __init__(self, device_manager: DeviceManager):
        self.device_manager = device_manager
        self._running = False
        self._active = False

    def start(self):
        """Start universal control service"""
        self._running = True
        logger.info("Universal Control service started")
        logger.info("Share your input devices with paired devices")

    def stop(self):
        self._running = False
        self._active = False

    def toggle(self):
        """Toggle universal control on/off"""
        self._active = not self._active
        status = "enabled" if self._active else "disabled"
        logger.info(f"Universal Control: {status}")
        return self._active

    def is_active(self) -> bool:
        return self._active


# =============================================================================
# Remote Device Management
# =============================================================================

class RemoteManagement:
    """Remote device management and control"""

    PORT = 36793

    def __init__(self, device_manager: DeviceManager):
        self.device_manager = device_manager
        self._running = False

    def start_server(self):
        """Start remote management server"""
        self._running = True
        threading.Thread(target=self._server_loop, daemon=True).start()
        logger.info("Remote management server started")

    def stop_server(self):
        self._running = False

    def _server_loop(self):
        """Listen for remote management commands"""
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

        try:
            sock.bind(("0.0.0.0", self.PORT))
            sock.listen(5)
            sock.settimeout(1)

            while self._running:
                try:
                    conn, addr = sock.accept()
                    threading.Thread(
                        target=self._handle_command,
                        args=(conn, addr),
                        daemon=True
                    ).start()
                except socket.timeout:
                    continue
        finally:
            sock.close()

    def _handle_command(self, conn: socket.socket, addr):
        """Handle remote management command"""
        try:
            data = conn.recv(4096)
            command = json.loads(data.decode())

            cmd_type = command.get("type")
            cmd_action = command.get("action")

            response = {"status": "error", "message": "Unknown command"}

            if cmd_type == "system":
                response = self._handle_system_command(cmd_action, command)
            elif cmd_type == "file":
                response = self._handle_file_command(cmd_action, command)
            elif cmd_type == "clipboard":
                response = self._handle_clipboard_command(cmd_action, command)

            conn.send(json.dumps(response).encode())

        except Exception as e:
            logger.error(f"Remote command error: {e}")
        finally:
            conn.close()

    def _handle_system_command(self, action: str, params: Dict) -> Dict:
        """Handle system commands"""
        if action == "info":
            import psutil
            return {
                "status": "ok",
                "data": {
                    "hostname": socket.gethostname(),
                    "cpu_percent": psutil.cpu_percent(),
                    "memory": dict(psutil.virtual_memory()._asdict()),
                    "disk": dict(psutil.disk_usage('/')._asdict()),
                    "boot_time": psutil.boot_time(),
                }
            }
        elif action == "lock":
            subprocess.run(["swaylock"], capture_output=True)
            return {"status": "ok", "message": "Screen locked"}
        elif action == "notify":
            message = params.get("message", "")
            subprocess.run([
                "notify-send", "OrionOS Remote", message,
                "-i", "computer", "-a", "OrionOS Remote"
            ], capture_output=True)
            return {"status": "ok", "message": "Notification sent"}

        return {"status": "error", "message": f"Unknown action: {action}"}

    def _handle_file_command(self, action: str, params: Dict) -> Dict:
        """Handle file commands"""
        if action == "list":
            path = Path(params.get("path", "/"))
            try:
                items = []
                for item in path.iterdir():
                    items.append({
                        "name": item.name,
                        "type": "directory" if item.is_dir() else "file",
                        "size": item.stat().st_size if item.is_file() else 0,
                    })
                return {"status": "ok", "data": items}
            except PermissionError:
                return {"status": "error", "message": "Permission denied"}

        return {"status": "error", "message": f"Unknown action: {action}"}

    def _handle_clipboard_command(self, action: str, params: Dict) -> Dict:
        """Handle clipboard commands"""
        if action == "get":
            try:
                result = subprocess.run(["wl-paste"], capture_output=True, text=True, timeout=5)
                return {"status": "ok", "data": result.stdout}
            except FileNotFoundError:
                return {"status": "error", "message": "Clipboard not available"}
        elif action == "set":
            text = params.get("text", "")
            try:
                process = subprocess.Popen(["wl-copy"], stdin=subprocess.PIPE, text=True)
                process.communicate(input=text)
                return {"status": "ok", "message": "Clipboard updated"}
            except FileNotFoundError:
                return {"status": "error", "message": "Clipboard not available"}

        return {"status": "error", "message": f"Unknown action: {action}"}

    def send_command(self, device: Device, command: Dict) -> Dict:
        """Send a remote command to a device"""
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(10)
            sock.connect((device.ip_address, self.PORT))
            sock.send(json.dumps(command).encode())

            response = json.loads(sock.recv(4096).decode())
            sock.close()
            return response

        except Exception as e:
            return {"status": "error", "message": str(e)}


# =============================================================================
# Main CLI
# =============================================================================

def main():
    parser = argparse.ArgumentParser(
        description='OrionOS Ecosystem Services',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  orionos-ecosystem discover              Discover nearby devices
  orionos-ecosystem pair <device-id>      Pair with a device
  orionos-ecosystem devices               List paired devices
  orionos-ecosystem share <file>          Share file to paired devices
  orionos-ecosystem clipboard             Start clipboard sync
  orionos-ecosystem cloud list            List cloud providers
  orionos-ecosystem cloud add <name> <type>  Add cloud provider
  orionos-ecosystem cloud sync            Sync with cloud
  orionos-ecosystem remote <device> info  Get remote device info
  orionos-ecosystem universal             Toggle universal control
        """
    )

    parser.add_argument('--config-dir', default=str(Path.home() / '.config/orionos/ecosystem'),
                       help='Configuration directory')
    parser.add_argument('--verbose', '-v', action='store_true', help='Verbose output')

    subparsers = parser.add_subparsers(dest='command', help='Commands')

    # Discover
    subparsers.add_parser('discover', help='Discover devices')

    # Pair
    pair_parser = subparsers.add_parser('pair', help='Pair with device')
    pair_parser.add_argument('device_id', help='Device ID')

    # Unpair
    unpair_parser = subparsers.add_parser('unpair', help='Unpair device')
    unpair_parser.add_argument('device_id', help='Device ID')

    # Devices
    subparsers.add_parser('devices', help='List devices')

    # Share
    share_parser = subparsers.add_parser('share', help='Share file')
    share_parser.add_argument('file', help='File to share')

    # Clipboard
    clipboard_parser = subparsers.add_parser('clipboard', help='Clipboard sync')
    clipboard_parser.add_argument('--start', action='store_true', help='Start server')
    clipboard_parser.add_argument('--stop', action='store_true', help='Stop server')

    # Cloud
    cloud_parser = subparsers.add_parser('cloud', help='Cloud sync')
    cloud_subparsers = cloud_parser.add_subparsers(dest='cloud_cmd')
    cloud_subparsers.add_parser('list', help='List providers')
    cloud_add = cloud_subparsers.add_parser('add', help='Add provider')
    cloud_add.add_argument('name', help='Provider name')
    cloud_add.add_argument('type', choices=list(CloudSync.SUPPORTED_PROVIDERS.keys()))
    cloud_add.add_argument('--server-url', help='Server URL')
    cloud_add.add_argument('--username', help='Username')
    cloud_add.add_argument('--password', help='Password')
    cloud_subparsers.add_parser('sync', help='Sync all')

    # Remote
    remote_parser = subparsers.add_parser('remote', help='Remote management')
    remote_parser.add_argument('device', help='Device name or ID')
    remote_parser.add_argument('action', choices=['info', 'lock', 'notify'])
    remote_parser.add_argument('--message', help='Notification message')

    # Universal Control
    subparsers.add_parser('universal', help='Toggle universal control')

    args = parser.parse_args()

    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    config_dir = Path(args.config_dir)
    config_dir.mkdir(parents=True, exist_ok=True)

    device_manager = DeviceManager(config_dir)

    if args.command == 'discover':
        print("Discovering devices...")
        devices = device_manager.discover_devices()
        if devices:
            print(f"\nFound {len(devices)} device(s):\n")
            for dev in devices:
                print(f"  {dev.name} ({dev.type})")
                print(f"    ID: {dev.id}")
                print(f"    IP: {dev.ip_address}")
                print(f"    Capabilities: {', '.join(dev.capabilities)}")
                print()
        else:
            print("No devices found. Make sure devices are on the same network.")

    elif args.command == 'pair':
        if device_manager.pair_device(args.device_id):
            print(f"Successfully paired with device")
        else:
            print("Failed to pair device")
            sys.exit(1)

    elif args.command == 'unpair':
        if device_manager.unpair_device(args.device_id):
            print("Device unpaired")
        else:
            print("Device not found")

    elif args.command == 'devices':
        devices = device_manager.get_paired_devices()
        if devices:
            print(f"Paired devices ({len(devices)}):\n")
            for dev in devices:
                status = "🟢" if (time.time() - dev.last_seen) < 60 else "⚪"
                print(f"  {status} {dev.name} ({dev.type})")
                print(f"     IP: {dev.ip_address}")
                print(f"     Last seen: {time.time() - dev.last_seen:.0f}s ago")
        else:
            print("No paired devices. Use 'discover' to find devices.")

    elif args.command == 'share':
        nearby = NearbyShare(device_manager)
        nearby.start_server()
        nearby.share_file(args.file)

    elif args.command == 'clipboard':
        clipboard = ClipboardSync(device_manager)

        if args.start:
            clipboard.start_server()
            print("Clipboard sync started. Press Ctrl+C to stop.")
            try:
                clipboard.start_monitoring()
            except KeyboardInterrupt:
                clipboard.stop_server()
                print("Clipboard sync stopped.")
        elif args.stop:
            clipboard.stop_server()
            print("Clipboard sync stopped.")
        else:
            print("Use --start or --stop")

    elif args.command == 'cloud':
        cloud = CloudSync(config_dir)

        if args.cloud_cmd == 'list':
            providers = cloud.list_providers()
            if providers:
                for name, config in providers.items():
                    print(f"  {name} ({config['type']}) - {'enabled' if config.get('enabled') else 'disabled'}")
            else:
                print("No cloud providers configured.")

        elif args.cloud_cmd == 'add':
            provider_config = {}
            if args.server_url:
                provider_config['server_url'] = args.server_url
            if args.username:
                provider_config['username'] = args.username
            if args.password:
                provider_config['password'] = args.password

            cloud.add_provider(args.name, args.type, provider_config)

        elif args.cloud_cmd == 'sync':
            cloud.sync()

    elif args.command == 'remote':
        remote = RemoteManagement(device_manager)

        # Find device
        target_device = None
        for dev in device_manager.devices.values():
            if dev.name == args.device or dev.id == args.device:
                target_device = dev
                break

        if not target_device:
            print(f"Device not found: {args.device}")
            sys.exit(1)

        command = {
            "type": "system",
            "action": args.action,
        }
        if args.message:
            command["message"] = args.message

        result = remote.send_command(target_device, command)
        print(json.dumps(result, indent=2))

    elif args.command == 'universal':
        uc = UniversalControl(device_manager)
        uc.start()
        active = uc.toggle()
        print(f"Universal Control: {'enabled' if active else 'disabled'}")

    else:
        parser.print_help()


if __name__ == '__main__':
    main()
