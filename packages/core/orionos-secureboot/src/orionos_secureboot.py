#!/usr/bin/env python3
"""
OrionOS Secure Boot Manager
Provides Secure Boot key management, kernel signing, and verification.
"""

import os
import sys
import json
import subprocess
import logging
import shutil
from pathlib import Path
from typing import Optional, List, Dict
from dataclasses import dataclass, asdict

CONFIG_DIR = Path("/etc/orionos")
KEY_DIR = Path("/var/lib/orionos/secureboot/keys")
LOG_DIR = Path("/var/log/orio nos")
LOG_DIR.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.FileHandler(LOG_DIR / "secureboot.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("orionos-secureboot")


@dataclass
class SecureBootConfig:
    key_dir: str = str(KEY_DIR)
    auto_sign_kernels: bool = True
    sign_after_update: bool = True
    enroll_on_install: bool = True
    tpm_seal_keys: bool = True
    mok_enrollment: bool = True
    fallback_signer: bool = True
    dbx_update: bool = True


class SecureBootManager:
    def __init__(self, config: SecureBootConfig):
        self.config = config
        self.key_dir = Path(config.key_dir)

    def get_status(self) -> Dict[str, str]:
        status = {}
        try:
            result = subprocess.run(["mokutil", "--sb-state"], capture_output=True, text=True)
            status["secureboot"] = result.stdout.strip()
        except FileNotFoundError:
            status["secureboot"] = "mokutil not installed"

        status["uefi"] = str(Path("/sys/firmware/efi").exists())

        try:
            result = subprocess.run(["tpm2_getcap", "properties-fixed"], capture_output=True, text=True)
            status["tpm"] = "available" if result.returncode == 0 else "not available"
        except FileNotFoundError:
            status["tpm"] = "tpm2-tools not installed"

        return status

    def generate_keys(self):
        logger.info("Generating Secure Boot keys...")
        for key_name in ["PK", "KEK", "db", "dbx"]:
            key_path = self.key_dir / key_name
            key_path.mkdir(parents=True, exist_ok=True)

            cn = {
                "PK": "OrionOS Platform Key (PK)",
                "KEK": "OrionOS Key Exchange Key (KEK)",
                "db": "OrionOS Signature Database (db)",
                "dbx": "OrionOS Signature Blacklist (dbx)",
            }[key_name]

            subprocess.run([
                "openssl", "req", "-new", "-x509", "-newkey", "rsa:2048",
                "-sha256", "-days", "3650", "-nodes",
                "-subj", f"/CN={cn}/O=OrionOS/C=US",
                "-keyout", str(key_path / f"{key_name}.key"),
                "-out", str(key_path / f"{key_name}.crt"),
            ], capture_output=True)

            subprocess.run([
                "openssl", "x509", "-outform", "DER",
                "-in", str(key_path / f"{key_name}.crt"),
                "-out", str(key_path / f"{key_name}.der"),
            ], capture_output=True)

            os.chmod(str(key_path / f"{key_name}.key"), 0o600)

        logger.info("All keys generated successfully")

    def sign_kernel(self, kernel_path: str) -> bool:
        kernel = Path(kernel_path)
        if not kernel.exists():
            logger.error(f"Kernel not found: {kernel_path}")
            return False

        db_key = self.key_dir / "db" / "db.key"
        db_cert = self.key_dir / "db" / "db.crt"

        if not db_key.exists() or not db_cert.exists():
            logger.error("Signing keys not found. Generate keys first.")
            return False

        signed_path = str(kernel) + ".signed"
        result = subprocess.run([
            "sbsign",
            "--key", str(db_key),
            "--cert", str(db_cert),
            "--output", signed_path,
            str(kernel),
        ], capture_output=True)

        if result.returncode == 0:
            shutil.move(signed_path, str(kernel))
            logger.info(f"Kernel signed: {kernel_path}")
            return True
        else:
            logger.error(f"Failed to sign kernel: {result.stderr.decode()}")
            return False

    def sign_all_kernels(self) -> int:
        count = 0
        for kernel in Path("/boot").glob("vmlinuz-linux*"):
            if self.sign_kernel(str(kernel)):
                count += 1
        return count

    def verify_kernel(self, kernel_path: str) -> bool:
        db_cert = self.key_dir / "db" / "db.crt"
        if not db_cert.exists():
            return False

        result = subprocess.run([
            "sbverify",
            "--cert", str(db_cert),
            kernel_path,
        ], capture_output=True)
        return result.returncode == 0

    def get_signed_kernels(self) -> Dict[str, bool]:
        result = {}
        for kernel in Path("/boot").glob("vmlinuz-linux*"):
            result[str(kernel)] = self.verify_kernel(str(kernel))
        return result


def load_config() -> SecureBootConfig:
    config_file = CONFIG_DIR / "secureboot.conf"
    if config_file.exists():
        try:
            with open(config_file) as f:
                return SecureBootConfig(**json.load(f))
        except (json.JSONDecodeError, TypeError):
            pass
    return SecureBootConfig()


def main():
    import argparse
    parser = argparse.ArgumentParser(description="OrionOS Secure Boot Manager")
    parser.add_argument("action", choices=["status", "generate-keys", "sign-kernel", "sign-all", "verify"],
                        help="Action to perform")
    parser.add_argument("--kernel", help="Kernel path for sign-kernel action")

    args = parser.parse_args()
    config = load_config()
    manager = SecureBootManager(config)

    if args.action == "status":
        status = manager.get_status()
        for k, v in status.items():
            print(f"  {k}: {v}")

    elif args.action == "generate-keys":
        manager.generate_keys()

    elif args.action == "sign-kernel":
        if not args.kernel:
            print("--kernel required", file=sys.stderr)
            sys.exit(1)
        manager.sign_kernel(args.kernel)

    elif args.action == "sign-all":
        count = manager.sign_all_kernels()
        print(f"Signed {count} kernel(s)")

    elif args.action == "verify":
        signed = manager.get_signed_kernels()
        for path, is_signed in signed.items():
            status = "SIGNED" if is_signed else "NOT SIGNED"
            print(f"  {path}: {status}")


if __name__ == "__main__":
    main()
