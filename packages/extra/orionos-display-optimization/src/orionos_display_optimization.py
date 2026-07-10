#!/usr/bin/env python3
"""
OrionOS Display Optimization
HDR, VRR, and display improvements
"""

import os
import sys
import json
import time
import signal
import logging
import argparse
import subprocess
from pathlib import Path
from typing import Optional, Dict, List
from dataclasses import dataclass, asdict
from enum import Enum

# Configuration paths
CONFIG_DIR = Path("/etc/orionos")
DATA_DIR = Path("/var/lib/orionos/display-optimization")
LOG_DIR = Path("/var/log/orionos")

LOG_DIR.mkdir(parents=True, exist_ok=True)
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.FileHandler(LOG_DIR / "display-optimization.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("orionos-display-optimization")


class DisplayMode(Enum):
    DEFAULT = "default"
    HDR = "hdr"
    VRR = "vrr"
    HDR_VRR = "hdr_vrr"
    GAMING = "gaming"
    PRODUCTIVITY = "productivity"


@dataclass
class DisplayProfile:
    name: str
    hdr_enabled: bool
    vrr_enabled: bool
    refresh_rate: Optional[int]
    color_depth: int
    color_space: str
    gamma: float
    brightness: float
    contrast: float
    saturation: float
    sharpness: float
    ambient_light: bool
    blue_light_filter: bool
    blue_light_intensity: float


@dataclass
class DisplayConfig:
    auto_detect: bool = True
    default_profile: str = "default"
    monitor_interval: float = 2.0
    display_directories: List[str] = None
    ignore_displays: List[str] = None
    hdr_support: bool = True
    vrr_support: bool = True
    color_management: bool = True
    ambient_light_adaptation: bool = True

    def __post_init__(self):
        if self.display_directories is None:
            self.display_directories = [
                "/sys/class/drm",
                "/sys/class/backlight",
                "/sys/class/leds",
            ]
        if self.ignore_displays is None:
            self.ignore_displays = ["eDP-1"]


class DisplayOptimizer:
    """Main display optimization daemon"""
    
    def __init__(self, config: DisplayConfig):
        self.config = config
        self.current_profile: Optional[DisplayProfile] = None
        self.profiles: Dict[str, DisplayProfile] = {}
        self.active_display: Optional[str] = None
        self.running = True
        
        self._load_profiles()
    
    def _load_profiles(self):
        """Load display profiles from configuration"""
        profiles_file = CONFIG_DIR / "display-profiles.json"
        
        if profiles_file.exists():
            with open(profiles_file) as f:
                data = json.load(f)
                for name, profile_data in data.items():
                    self.profiles[name] = DisplayProfile(**profile_data)
        else:
            self._create_default_profiles()
    
    def _create_default_profiles(self):
        """Create default display profiles"""
        self.profiles = {
            "default": DisplayProfile(
                name="default",
                hdr_enabled=False,
                vrr_enabled=False,
                refresh_rate=None,
                color_depth=8,
                color_space="sRGB",
                gamma=2.2,
                brightness=1.0,
                contrast=1.0,
                saturation=1.0,
                sharpness=1.0,
                ambient_light=False,
                blue_light_filter=False,
                blue_light_intensity=0.0
            ),
            "hdr": DisplayProfile(
                name="hdr",
                hdr_enabled=True,
                vrr_enabled=False,
                refresh_rate=None,
                color_depth=10,
                color_space="Rec.2020",
                gamma=2.4,
                brightness=1.0,
                contrast=1.2,
                saturation=1.1,
                sharpness=1.0,
                ambient_light=False,
                blue_light_filter=False,
                blue_light_intensity=0.0
            ),
            "vrr": DisplayProfile(
                name="vrr",
                hdr_enabled=False,
                vrr_enabled=True,
                refresh_rate=144,
                color_depth=8,
                color_space="sRGB",
                gamma=2.2,
                brightness=1.0,
                contrast=1.0,
                saturation=1.0,
                sharpness=1.0,
                ambient_light=False,
                blue_light_filter=False,
                blue_light_intensity=0.0
            ),
            "hdr_vrr": DisplayProfile(
                name="hdr_vrr",
                hdr_enabled=True,
                vrr_enabled=True,
                refresh_rate=144,
                color_depth=10,
                color_space="Rec.2020",
                gamma=2.4,
                brightness=1.0,
                contrast=1.2,
                saturation=1.1,
                sharpness=1.0,
                ambient_light=False,
                blue_light_filter=False,
                blue_light_intensity=0.0
            ),
            "gaming": DisplayProfile(
                name="gaming",
                hdr_enabled=True,
                vrr_enabled=True,
                refresh_rate=165,
                color_depth=10,
                color_space="Rec.2020",
                gamma=2.4,
                brightness=1.0,
                contrast=1.3,
                saturation=1.2,
                sharpness=1.1,
                ambient_light=False,
                blue_light_filter=False,
                blue_light_intensity=0.0
            ),
            "productivity": DisplayProfile(
                name="productivity",
                hdr_enabled=False,
                vrr_enabled=False,
                refresh_rate=60,
                color_depth=8,
                color_space="sRGB",
                gamma=2.2,
                brightness=0.8,
                contrast=1.0,
                saturation=1.0,
                sharpness=1.2,
                ambient_light=True,
                blue_light_filter=True,
                blue_light_intensity=0.3
            ),
        }
        
        profiles_file = CONFIG_DIR / "display-profiles.json"
        profiles_file.parent.mkdir(parents=True, exist_ok=True)
        
        with open(profiles_file, 'w') as f:
            json.dump({name: asdict(p) for name, p in self.profiles.items()}, f, indent=2)
    
    def start(self):
        """Start the display optimizer daemon"""
        logger.info("Starting OrionOS Display Optimization daemon")
        
        signal.signal(signal.SIGTERM, self._handle_signal)
        signal.signal(signal.SIGINT, self._handle_signal)
        
        self._set_profile(self.config.default_profile)
        
        if self.config.auto_detect:
            self._monitor_displays()
        else:
            self._run_daemon()
    
    def _handle_signal(self, signum, frame):
        """Handle system signals"""
        logger.info(f"Received signal {signum}, shutting down")
        self.running = False
        self._restore_defaults()
    
    def _run_daemon(self):
        """Run as daemon without auto-detection"""
        while self.running:
            time.sleep(1)
    
    def _monitor_displays(self):
        """Monitor for connected displays"""
        logger.info("Monitoring for connected displays")
        
        while self.running:
            try:
                display = self._detect_display()
                
                if display and not self.active_display:
                    logger.info(f"Display detected: {display}")
                    self.active_display = display
                    self._apply_display_profile(display)
                
                elif not display and self.active_display:
                    logger.info(f"Display disconnected: {self.active_display}")
                    self.active_display = None
                    self._restore_defaults()
                
                time.sleep(self.config.monitor_interval)
                
            except Exception as e:
                logger.error(f"Monitor error: {e}")
                time.sleep(1)
    
    def _detect_display(self) -> Optional[str]:
        """Detect connected displays"""
        try:
            # Use xrandr to detect displays
            result = subprocess.run(
                ["xrandr", "--query"],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            if result.returncode == 0:
                for line in result.stdout.split('\n'):
                    if ' connected' in line:
                        display_name = line.split()[0]
                        if display_name not in self.config.ignore_displays:
                            return display_name
            
            return None
            
        except Exception as e:
            logger.error(f"Display detection failed: {e}")
            return None
    
    def _apply_display_profile(self, display_name: str):
        """Apply optimization profile for detected display"""
        profile = self.profiles.get(self.config.default_profile, self.profiles["default"])
        
        logger.info(f"Applying profile: {profile.name} to {display_name}")
        
        # Apply HDR settings
        if self.config.hdr_support:
            self._apply_hdr_settings(profile, display_name)
        
        # Apply VRR settings
        if self.config.vrr_support:
            self._apply_vrr_settings(profile, display_name)
        
        # Apply color settings
        if self.config.color_management:
            self._apply_color_settings(profile, display_name)
        
        # Apply ambient light settings
        if self.config.ambient_light_adaptation:
            self._apply_ambient_light(profile, display_name)
    
    def _apply_hdr_settings(self, profile: DisplayProfile, display_name: str):
        """Apply HDR settings"""
        try:
            if profile.hdr_enabled:
                # Enable HDR via xrandr
                subprocess.run([
                    "xrandr", "--output", display_name,
                    "--set", "HDR", "1"
                ], capture_output=True)
                
                # Set color depth
                subprocess.run([
                    "xrandr", "--output", display_name,
                    "--set", "ColorDepth", str(profile.color_depth)
                ], capture_output=True)
                
                # Set color space
                subprocess.run([
                    "xrandr", "--output", display_name,
                    "--set", "ColorSpace", profile.color_space
                ], capture_output=True)
            
            logger.info(f"HDR settings applied: {profile.hdr_enabled}")
            
        except Exception as e:
            logger.error(f"Failed to apply HDR settings: {e}")
    
    def _apply_vrr_settings(self, profile: DisplayProfile, display_name: str):
        """Apply VRR settings"""
        try:
            if profile.vrr_enabled:
                # Enable VRR via xrandr
                subprocess.run([
                    "xrandr", "--output", display_name,
                    "--set", "VRR", "1"
                ], capture_output=True)
                
                # Set refresh rate if specified
                if profile.refresh_rate:
                    # Get current mode
                    result = subprocess.run([
                        "xrandr", "--output", display_name,
                        "--verbose"
                    ], capture_output=True, text=True)
                    
                    for line in result.stdout.split('\n'):
                        if 'Refresh Rate:' in line:
                            current_rate = float(line.split(':')[1].strip())
                            if current_rate != profile.refresh_rate:
                                # Find mode with target refresh rate
                                subprocess.run([
                                    "xrandr", "--output", display_name,
                                    "--mode", f"{profile.refresh_rate}Hz"
                                ], capture_output=True)
            
            logger.info(f"VRR settings applied: {profile.vrr_enabled}")
            
        except Exception as e:
            logger.error(f"Failed to apply VRR settings: {e}")
    
    def _apply_color_settings(self, profile: DisplayProfile, display_name: str):
        """Apply color settings"""
        try:
            # Set gamma
            subprocess.run([
                "xrandr", "--output", display_name,
                "--gamma", f"{profile.gamma}:{profile.gamma}:{profile.gamma}"
            ], capture_output=True)
            
            # Set brightness
            subprocess.run([
                "xrandr", "--output", display_name,
                "--brightness", str(profile.brightness)
            ], capture_output=True)
            
            # Set contrast (via gamma)
            contrast_gamma = profile.contrast * profile.gamma
            subprocess.run([
                "xrandr", "--output", display_name,
                "--gamma", f"{contrast_gamma}:{contrast_gamma}:{contrast_gamma}"
            ], capture_output=True)
            
            logger.info(f"Color settings applied: gamma={profile.gamma}, brightness={profile.brightness}")
            
        except Exception as e:
            logger.error(f"Failed to apply color settings: {e}")
    
    def _apply_ambient_light(self, profile: DisplayProfile, display_name: str):
        """Apply ambient light adaptation"""
        try:
            if profile.ambient_light:
                # Read ambient light sensor
                ambient_file = Path("/sys/class/backlight/amdgpu_bl0/ambient_light")
                if ambient_file.exists():
                    ambient_value = int(ambient_file.read_text().strip())
                    # Adjust brightness based on ambient light
                    brightness = profile.brightness * (ambient_value / 100)
                    subprocess.run([
                        "xrandr", "--output", display_name,
                        "--brightness", str(brightness)
                    ], capture_output=True)
            
            if profile.blue_light_filter:
                # Apply blue light filter
                blue_light_gamma = 1.0 - (profile.blue_light_intensity * 0.3)
                subprocess.run([
                    "xrandr", "--output", display_name,
                    "--gamma", f"{blue_light_gamma}:{blue_light_gamma}:{profile.gamma}"
                ], capture_output=True)
            
            logger.info("Ambient light adaptation applied")
            
        except Exception as e:
            logger.error(f"Failed to apply ambient light adaptation: {e}")
    
    def _restore_defaults(self):
        """Restore default settings"""
        logger.info("Restoring default settings")
        
        default_profile = self.profiles["default"]
        
        self._apply_hdr_settings(default_profile, "eDP-1")
        self._apply_vrr_settings(default_profile, "eDP-1")
        self._apply_color_settings(default_profile, "eDP-1")
        self._apply_ambient_light(default_profile, "eDP-1")
    
    def _set_profile(self, profile_name: str):
        """Set the active profile"""
        if profile_name in self.profiles:
            self.current_profile = self.profiles[profile_name]
            logger.info(f"Profile set to: {profile_name}")
        else:
            logger.warning(f"Profile not found: {profile_name}, using default")
            self.current_profile = self.profiles["default"]
    
    def list_profiles(self) -> List[str]:
        """List available profiles"""
        return list(self.profiles.keys())
    
    def get_current_profile(self) -> Optional[str]:
        """Get current active profile"""
        return self.current_profile.name if self.current_profile else None


def load_config() -> DisplayConfig:
    """Load configuration from file"""
    config_file = CONFIG_DIR / "display-optimization.conf"
    
    if config_file.exists():
        try:
            with open(config_file) as f:
                data = json.load(f)
            return DisplayConfig(**data)
        except (json.JSONDecodeError, TypeError) as e:
            logger.warning(f"Invalid config: {e}")
    
    return DisplayConfig()


def main():
    parser = argparse.ArgumentParser(description="OrionOS Display Optimization")
    parser.add_argument("--daemon", "-d", action="store_true",
                        help="Run as daemon")
    parser.add_argument("--profile", "-p", type=str, default="default",
                        help="Set display profile")
    parser.add_argument("--list-profiles", action="store_true",
                        help="List available profiles")
    parser.add_argument("--status", action="store_true",
                        help="Show current status")
    parser.add_argument("--auto-detect", action="store_true", default=True,
                        help="Enable auto-detection of displays")
    parser.add_argument("--no-auto-detect", action="store_true",
                        help="Disable auto-detection of displays")
    parser.add_argument("--detect-displays", action="store_true",
                        help="Detect and list connected displays")
    
    args = parser.parse_args()
    
    config = load_config()
    
    if args.no_auto_detect:
        config.auto_detect = False
    
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    
    optimizer = DisplayOptimizer(config)
    
    if args.list_profiles:
        profiles = optimizer.list_profiles()
        print("Available profiles:")
        for profile in profiles:
            print(f"  - {profile}")
        return
    
    if args.status:
        current = optimizer.get_current_profile()
        print(f"Current profile: {current or 'default'}")
        return
    
    if args.detect_displays:
        display = optimizer._detect_display()
        print(f"Detected display: {display or 'None'}")
        return
    
    if args.profile:
        optimizer._set_profile(args.profile)
    
    if args.daemon:
        optimizer.start()
    else:
        print("Use --daemon to run as a background service")


if __name__ == "__main__":
    main()
