#!/usr/bin/env python3
"""
OrionOS Game Optimization
Advanced game auto-optimization and performance tuning
"""

import os
import sys
import json
import time
import signal
import logging
import argparse
import subprocess
import inotify.adapters
from pathlib import Path
from typing import Optional, Dict, List
from dataclasses import dataclass, asdict
from enum import Enum

# Configuration paths
CONFIG_DIR = Path("/etc/orionos")
DATA_DIR = Path("/var/lib/orionos/game-optimize")
LOG_DIR = Path("/var/log/orionos")

LOG_DIR.mkdir(parents=True, exist_ok=True)
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.FileHandler(LOG_DIR / "game-optimize.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("orionos-game-optimize")


class GameMode(Enum):
    DEFAULT = "default"
    PERFORMANCE = "performance"
    BALANCED = "balanced"
    POWERSAVE = "powersave"
    GAMING = "gaming"


@dataclass
class GameProfile:
    name: str
    cpu_governor: str
    cpu_max_freq: Optional[int]
    cpu_min_freq: Optional[int]
    gpu_profile: str
    io_scheduler: str
    io_scheduler_params: Dict[str, str]
    vm_params: Dict[str, str]
    network_params: Dict[str, str]
    audio_params: Dict[str, str]
    process_priorities: Dict[str, int]
    env_vars: Dict[str, str]


@dataclass
class GameConfig:
    auto_detect: bool = True
    default_profile: str = "default"
    monitor_interval: float = 1.0
    game_directories: List[str] = None
    ignore_processes: List[str] = None
    gpu_power_management: bool = True
    cpu_performance_mode: bool = True
    io_optimization: bool = True
    network_optimization: bool = True
    audio_optimization: bool = True

    def __post_init__(self):
        if self.game_directories is None:
            self.game_directories = [
                str(Path.home() / "Games"),
                "/usr/share/games",
                "/opt/steam",
                str(Path.home() / ".local/share/Steam/steamapps/common"),
                str(Path.home() / ".steam/steam/steamapps/common"),
            ]
        if self.ignore_processes is None:
            self.ignore_processes = ["steam", "lutris", "heroic", "gamescope"]


class GameOptimizer:
    """Main game optimization daemon"""
    
    def __init__(self, config: GameConfig):
        self.config = config
        self.current_profile: Optional[GameProfile] = None
        self.profiles: Dict[str, GameProfile] = {}
        self.active_game: Optional[str] = None
        self.running = True
        
        self._load_profiles()
    
    def _load_profiles(self):
        """Load game profiles from configuration"""
        profiles_file = CONFIG_DIR / "game-profiles.json"
        
        if profiles_file.exists():
            with open(profiles_file) as f:
                data = json.load(f)
                for name, profile_data in data.items():
                    self.profiles[name] = GameProfile(**profile_data)
        else:
            self._create_default_profiles()
    
    def _create_default_profiles(self):
        """Create default game profiles"""
        self.profiles = {
            "default": GameProfile(
                name="default",
                cpu_governor="schedutil",
                cpu_max_freq=None,
                cpu_min_freq=None,
                gpu_profile="auto",
                io_scheduler="mq-deadline",
                io_scheduler_params={"read_ahead_kb": "256"},
                vm_params={"swappiness": "10", "dirty_ratio": "10"},
                network_params={"tcp_congestion_control": "bbr"},
                audio_params={"period_size": "256", "buffer_size": "1024"},
                process_priorities={"game": -10, "audio": -5},
                env_vars={"__GL_THREADED_OPTIMIZATIONS": "1", "MESA_NO_ERROR": "1"}
            ),
            "performance": GameProfile(
                name="performance",
                cpu_governor="performance",
                cpu_max_freq=None,
                cpu_min_freq=None,
                gpu_profile="high",
                io_scheduler="none",
                io_scheduler_params={"read_ahead_kb": "512"},
                vm_params={"swappiness": "5", "dirty_ratio": "5"},
                network_params={"tcp_congestion_control": "bbr"},
                audio_params={"period_size": "128", "buffer_size": "512"},
                process_priorities={"game": -20, "audio": -10},
                env_vars={"__GL_THREADED_OPTIMIZATIONS": "1", "MESA_NO_ERROR": "1", "vblank_mode": "0"}
            ),
            "gaming": GameProfile(
                name="gaming",
                cpu_governor="performance",
                cpu_max_freq=None,
                cpu_min_freq=None,
                gpu_profile="maximum",
                io_scheduler="none",
                io_scheduler_params={"read_ahead_kb": "1024"},
                vm_params={"swappiness": "1", "dirty_ratio": "5"},
                network_params={"tcp_congestion_control": "bbr"},
                audio_params={"period_size": "64", "buffer_size": "256"},
                process_priorities={"game": -20, "audio": -15, "steam": -10},
                env_vars={"__GL_THREADED_OPTIMIZATIONS": "1", "MESA_NO_ERROR": "1", "vblank_mode": "0", "gamemode": "1"}
            ),
        }
        
        profiles_file = CONFIG_DIR / "game-profiles.json"
        profiles_file.parent.mkdir(parents=True, exist_ok=True)
        
        with open(profiles_file, 'w') as f:
            json.dump({name: asdict(p) for name, p in self.profiles.items()}, f, indent=2)
    
    def start(self):
        """Start the game optimizer daemon"""
        logger.info("Starting OrionOS Game Optimization daemon")
        
        signal.signal(signal.SIGTERM, self._handle_signal)
        signal.signal(signal.SIGINT, self._handle_signal)
        
        self._set_profile(self.config.default_profile)
        
        if self.config.auto_detect:
            self._monitor_games()
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
    
    def _monitor_games(self):
        """Monitor for running games"""
        logger.info("Monitoring for running games")
        
        while self.running:
            try:
                game_process = self._detect_game()
                
                if game_process and not self.active_game:
                    logger.info(f"Game detected: {game_process}")
                    self.active_game = game_process
                    self._apply_game_profile(game_process)
                
                elif not game_process and self.active_game:
                    logger.info(f"Game exited: {self.active_game}")
                    self.active_game = None
                    self._restore_defaults()
                
                time.sleep(self.config.monitor_interval)
                
            except Exception as e:
                logger.error(f"Monitor error: {e}")
                time.sleep(1)
    
    def _detect_game(self) -> Optional[str]:
        """Detect if a game is running"""
        try:
            import psutil
            
            for proc in psutil.process_iter(['name', 'exe', 'cmdline']):
                try:
                    name = proc.info['name'].lower()
                    exe = proc.info['exe'] or ""
                    
                    # Check common game processes
                    game_indicators = [
                        "game", "steam", "proton", "wine",
                        "lutris", "heroic", "gamescope",
                        "vkBasalt", "mangohud", "gamemode",
                    ]
                    
                    for indicator in game_indicators:
                        if indicator.lower() in name or indicator.lower() in exe.lower():
                            return proc.info['name']
                    
                    # Check if process is in game directories
                    for game_dir in self.config.game_directories:
                        if game_dir in exe:
                            return proc.info['name']
                
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    continue
            
            return None
            
        except ImportError:
            return None
    
    def _apply_game_profile(self, game_name: str):
        """Apply optimization profile for detected game"""
        profile = self.profiles.get(self.config.default_profile, self.profiles["default"])
        
        logger.info(f"Applying profile: {profile.name}")
        
        # Apply CPU settings
        if self.config.cpu_performance_mode:
            self._apply_cpu_settings(profile)
        
        # Apply GPU settings
        if self.config.gpu_power_management:
            self._apply_gpu_settings(profile)
        
        # Apply I/O settings
        if self.config.io_optimization:
            self._apply_io_settings(profile)
        
        # Apply network settings
        if self.config.network_optimization:
            self._apply_network_settings(profile)
        
        # Apply process priorities
        self._apply_process_priorities(profile)
        
        # Apply environment variables
        self._apply_environment(profile)
    
    def _apply_cpu_settings(self, profile: GameProfile):
        """Apply CPU governor and frequency settings"""
        try:
            # Set governor
            for cpu in Path("/sys/devices/system/cpu").glob("cpu[0-9]*"):
                governor_file = cpu / "cpufreq" / "scaling_governor"
                if governor_file.exists():
                    governor_file.write_text(profile.cpu_governor)
            
            logger.info(f"CPU governor set to: {profile.cpu_governor}")
            
        except Exception as e:
            logger.error(f"Failed to apply CPU settings: {e}")
    
    def _apply_gpu_settings(self, profile: GameProfile):
        """Apply GPU profile settings"""
        try:
            # NVIDIA
            nvidia_smi = Path("/usr/bin/nvidia-smi")
            if nvidia_smi.exists():
                subprocess.run([str(nvidia_smi), "-pm", "1"], capture_output=True)
                subprocess.run([str(nvidia_smi), "-pl", "100"], capture_output=True)
            
            # AMD
            for card in Path("/sys/class/drm").glob("card[0-9]*"):
                power_method = card / "device" / "power_method"
                if power_method.exists():
                    power_method.write_text("profile")
                    
                    profile_file = card / "device" / "power_profile"
                    if profile_file.exists():
                        profile_file.write_text(profile.gpu_profile)
            
            logger.info(f"GPU profile set to: {profile.gpu_profile}")
            
        except Exception as e:
            logger.error(f"Failed to apply GPU settings: {e}")
    
    def _apply_io_settings(self, profile: GameProfile):
        """Apply I/O scheduler settings"""
        try:
            for block in Path("/sys/block").glob("*"):
                scheduler_file = block / "queue" / "scheduler"
                if scheduler_file.exists():
                    scheduler_file.write_text(profile.io_scheduler)
                
                for param, value in profile.io_scheduler_params.items():
                    param_file = block / "queue" / param
                    if param_file.exists():
                        param_file.write_text(value)
            
            logger.info(f"I/O scheduler set to: {profile.io_scheduler}")
            
        except Exception as e:
            logger.error(f"Failed to apply I/O settings: {e}")
    
    def _apply_network_settings(self, profile: GameProfile):
        """Apply network optimizations"""
        try:
            sysctl_path = Path("/proc/sys/net")
            
            for param, value in profile.network_params.items():
                param_file = sysctl_path / param.replace(".", "/")
                if param_file.exists():
                    param_file.write_text(value)
            
            logger.info("Network optimizations applied")
            
        except Exception as e:
            logger.error(f"Failed to apply network settings: {e}")
    
    def _apply_process_priorities(self, profile: GameProfile):
        """Apply process priorities"""
        try:
            import psutil
            
            for proc in psutil.process_iter(['name', 'nice']):
                try:
                    name = proc.info['name'].lower()
                    
                    for pattern, priority in profile.process_priorities.items():
                        if pattern in name:
                            proc.nice(priority)
                            logger.debug(f"Set {name} priority to {priority}")
                
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    continue
            
        except ImportError:
            pass
    
    def _apply_environment(self, profile: GameProfile):
        """Apply environment variables"""
        for key, value in profile.env_vars.items():
            os.environ[key] = value
        
        logger.info("Environment variables applied")
    
    def _restore_defaults(self):
        """Restore default settings"""
        logger.info("Restoring default settings")
        
        default_profile = self.profiles["default"]
        
        self._apply_cpu_settings(default_profile)
        self._apply_gpu_settings(default_profile)
        self._apply_io_settings(default_profile)
        self._apply_network_settings(default_profile)
    
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


def load_config() -> GameConfig:
    """Load configuration from file"""
    config_file = CONFIG_DIR / "game-optimize.conf"
    
    if config_file.exists():
        try:
            with open(config_file) as f:
                data = json.load(f)
            return GameConfig(**data)
        except (json.JSONDecodeError, TypeError) as e:
            logger.warning(f"Invalid config: {e}")
    
    return GameConfig()


def main():
    parser = argparse.ArgumentParser(description="OrionOS Game Optimization")
    parser.add_argument("--daemon", "-d", action="store_true",
                        help="Run as daemon")
    parser.add_argument("--profile", "-p", type=str, default="default",
                        help="Set performance profile")
    parser.add_argument("--list-profiles", action="store_true",
                        help="List available profiles")
    parser.add_argument("--status", action="store_true",
                        help="Show current status")
    parser.add_argument("--auto-detect", action="store_true", default=True,
                        help="Enable auto-detection of games")
    parser.add_argument("--no-auto-detect", action="store_true",
                        help="Disable auto-detection of games")
    
    args = parser.parse_args()
    
    config = load_config()
    
    if args.no_auto_detect:
        config.auto_detect = False
    
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    
    optimizer = GameOptimizer(config)
    
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
    
    if args.profile:
        optimizer._set_profile(args.profile)
    
    if args.daemon:
        optimizer.start()
    else:
        print("Use --daemon to run as a background service")


if __name__ == "__main__":
    main()
