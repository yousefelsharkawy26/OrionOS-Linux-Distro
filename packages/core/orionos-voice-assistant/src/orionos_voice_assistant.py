#!/usr/bin/env python3
"""
OrionOS Voice Assistant
Speech-to-text and text-to-speech with GPU acceleration
"""

import os
import sys
import json
import time
import queue
import threading
import logging
import argparse
import signal
from pathlib import Path
from typing import Optional, Dict, List
from dataclasses import dataclass
from enum import Enum

# Configuration paths
CONFIG_DIR = Path("/etc/orionos")
DATA_DIR = Path("/var/lib/orionos/voice-assistant")
MODEL_DIR = Path("/usr/share/orionos-voice-assistant/models")
LOG_DIR = Path("/var/log/orionos")

# Setup logging
LOG_DIR.mkdir(parents=True, exist_ok=True)
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.FileHandler(LOG_DIR / "voice-assistant.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("orionos-voice-assistant")


class VoiceState(Enum):
    IDLE = "idle"
    LISTENING = "listening"
    PROCESSING = "processing"
    SPEAKING = "speaking"


@dataclass
class VoiceConfig:
    # STT settings
    stt_model: str = "base"
    stt_language: str = "en"
    stt_device: str = "auto"
    
    # TTS settings
    tts_model: str = "default"
    tts_voice: str = "en_US-lessac-medium"
    tts_speaker_id: int = 0
    tts_length_scale: float = 1.0
    tts_noise_scale: float = 0.667
    tts_noise_w: float = 0.8
    
    # Audio settings
    sample_rate: int = 16000
    channels: int = 1
    chunk_size: int = 1024
    
    # Wake word
    wake_word_enabled: bool = True
    wake_word: str = "hey orion"
    wake_word_sensitivity: float = 0.5
    
    # VAD settings
    vad_enabled: bool = True
    vad_sensitivity: float = 0.5
    vad_timeout: float = 1.0
    
    # GPU settings
    gpu_enabled: bool = True
    gpu_device: str = "auto"


class VoiceAssistant:
    """Main voice assistant class"""
    
    def __init__(self, config: VoiceConfig):
        self.config = config
        self.state = VoiceState.IDLE
        self.audio_queue = queue.Queue()
        self.text_queue = queue.Queue()
        
        # Initialize components
        self.stt_engine = None
        self.tts_engine = None
        self.vad = None
        self.wake_word_detector = None
        
        self._initialize_components()
    
    def _initialize_components(self):
        """Initialize STT, TTS, and VAD components"""
        try:
            import whisper
            import piper
            import webrtcvad
            
            # Initialize STT
            logger.info(f"Loading STT model: {self.config.stt_model}")
            self.stt_engine = whisper.load_model(
                self.config.stt_model,
                device=self.config.stt_device
            )
            
            # Initialize TTS
            logger.info(f"Loading TTS model: {self.config.tts_model}")
            self.tts_engine = piper.PiperVoice.load(
                MODEL_DIR / f"{self.config.tts_model}.onnx"
            )
            
            # Initialize VAD
            if self.config.vad_enabled:
                self.vad = webrtcvad.Vad(int(self.config.vad_sensitivity * 3))
            
            # Initialize wake word detector
            if self.config.wake_word_enabled:
                self._init_wake_word_detector()
            
            logger.info("Voice assistant components initialized")
            
        except ImportError as e:
            logger.error(f"Failed to import dependencies: {e}")
            raise
    
    def _init_wake_word_detector(self):
        """Initialize wake word detection"""
        try:
            from openwakeword.model import Model as WakeWordModel
            
            self.wake_word_detector = WakeWordModel(
                wakeword_models=[self.config.wake_word]
            )
            logger.info(f"Wake word detector initialized: {self.config.wake_word}")
            
        except ImportError:
            logger.warning("openwakeword not available, wake word detection disabled")
            self.config.wake_word_enabled = False
    
    def start(self):
        """Start the voice assistant"""
        logger.info("Starting OrionOS Voice Assistant")
        
        # Start audio capture thread
        self.audio_thread = threading.Thread(target=self._audio_capture_loop, daemon=True)
        self.audio_thread.start()
        
        # Start processing thread
        self.processing_thread = threading.Thread(target=self._processing_loop, daemon=True)
        self.processing_thread.start()
        
        # Start TTS thread
        self.tts_thread = threading.Thread(target=self._tts_loop, daemon=True)
        self.tts_thread.start()
        
        # Main loop
        self._main_loop()
    
    def _main_loop(self):
        """Main event loop"""
        while True:
            try:
                # Check for commands
                if not self.text_queue.empty():
                    command = self.text_queue.get()
                    self._process_command(command)
                
                time.sleep(0.1)
                
            except KeyboardInterrupt:
                logger.info("Shutting down voice assistant")
                break
            except Exception as e:
                logger.error(f"Main loop error: {e}")
                time.sleep(1)
    
    def _audio_capture_loop(self):
        """Capture audio from microphone"""
        try:
            import sounddevice as sd
            
            with sd.InputStream(
                samplerate=self.config.sample_rate,
                channels=self.config.channels,
                blocksize=self.config.chunk_size,
                callback=self._audio_callback
            ):
                while True:
                    time.sleep(0.1)
                    
        except Exception as e:
            logger.error(f"Audio capture error: {e}")
    
    def _audio_callback(self, indata, frames, time_info, status):
        """Audio input callback"""
        if status:
            logger.warning(f"Audio status: {status}")
        
        # Add to queue for processing
        self.audio_queue.put(indata.copy())
    
    def _processing_loop(self):
        """Process audio for speech recognition"""
        while True:
            try:
                if not self.audio_queue.empty():
                    audio_data = self.audio_queue.get()
                    
                    # VAD check
                    if self.config.vad_enabled and self.vad:
                        if not self._is_speech(audio_data):
                            continue
                    
                    # Wake word detection
                    if self.config.wake_word_enabled and self.wake_word_detector:
                        if not self._detect_wake_word(audio_data):
                            continue
                    
                    # Speech to text
                    self.state = VoiceState.PROCESSING
                    text = self._speech_to_text(audio_data)
                    
                    if text:
                        logger.info(f"Recognized: {text}")
                        self.text_queue.put(text)
                    
                    self.state = VoiceState.IDLE
                
                time.sleep(0.01)
                
            except Exception as e:
                logger.error(f"Processing error: {e}")
                time.sleep(0.1)
    
    def _is_speech(self, audio_data) -> bool:
        """Check if audio contains speech using VAD"""
        try:
            import numpy as np
            
            # Convert to bytes for webrtcvad
            audio_bytes = (audio_data * 32767).astype(np.int16).tobytes()
            
            # Check speech
            return self.vad.is_speech(audio_bytes, self.config.sample_rate)
            
        except Exception:
            return True
    
    def _detect_wake_word(self, audio_data) -> bool:
        """Detect wake word in audio"""
        try:
            prediction = self.wake_word_detector.predict(audio_data)
            
            for model_name, scores in prediction.items():
                for word, score in scores.items():
                    if score > self.config.wake_word_sensitivity:
                        logger.info(f"Wake word detected: {word} (score: {score:.2f})")
                        return True
            
            return False
            
        except Exception:
            return True
    
    def _speech_to_text(self, audio_data) -> Optional[str]:
        """Convert speech to text"""
        try:
            import numpy as np
            
            # Convert to float32
            audio_float = audio_data.astype(np.float32) / 32767.0
            
            # Transcribe
            result = self.stt_engine.transcribe(
                audio_float,
                language=self.config.stt_language,
                fp16=False
            )
            
            text = result["text"].strip()
            return text if text else None
            
        except Exception as e:
            logger.error(f"STT error: {e}")
            return None
    
    def _tts_loop(self):
        """Text to speech output loop"""
        while True:
            try:
                if not self.text_queue.empty():
                    text = self.text_queue.get()
                    self._text_to_speech(text)
                
                time.sleep(0.1)
                
            except Exception as e:
                logger.error(f"TTS error: {e}")
                time.sleep(0.1)
    
    def _text_to_speech(self, text: str):
        """Convert text to speech"""
        try:
            import sounddevice as sd
            import numpy as np
            
            self.state = VoiceState.SPEAKING
            
            # Generate audio
            audio = self.tts_engine.synthesize(
                text,
                speaker_id=self.config.tts_speaker_id,
                length_scale=self.config.tts_length_scale,
                noise_scale=self.config.noise_scale,
                noise_w=self.config.noise_w
            )
            
            # Play audio
            sd.play(audio, self.config.sample_rate)
            sd.wait()
            
            self.state = VoiceState.IDLE
            
        except Exception as e:
            logger.error(f"TTS error: {e}")
            self.state = VoiceState.IDLE
    
    def _process_command(self, command: str):
        """Process voice command"""
        logger.info(f"Processing command: {command}")
        
        # Simple command processing
        command_lower = command.lower()
        
        if "hello" in command_lower or "hi" in command_lower:
            self.text_queue.put("Hello! How can I help you?")
        
        elif "what time" in command_lower:
            from datetime import datetime
            now = datetime.now()
            self.text_queue.put(f"The current time is {now.strftime('%I:%M %p')}")
        
        elif "what date" in command_lower:
            from datetime import datetime
            now = datetime.now()
            self.text_queue.put(f"Today is {now.strftime('%B %d, %Y')}")
        
        elif "open" in command_lower:
            # Extract app name
            app_name = command_lower.replace("open", "").strip()
            self._open_application(app_name)
        
        elif "search" in command_lower:
            query = command_lower.replace("search", "").strip()
            self._search_web(query)
        
        else:
            self.text_queue.put("I'm not sure how to help with that. Can you try again?")
    
    def _open_application(self, app_name: str):
        """Open an application by name"""
        import subprocess
        
        app_map = {
            "browser": "firefox",
            "terminal": "konsole",
            "files": "dolphin",
            "settings": "systemsettings",
            "calculator": "kalgebra",
            "text editor": "kate",
            "music": "elisa",
            "video": "vlc",
        }
        
        app_command = app_map.get(app_name, app_name)
        
        try:
            subprocess.Popen([app_command])
            self.text_queue.put(f"Opening {app_name}")
        except FileNotFoundError:
            self.text_queue.put(f"Sorry, I couldn't find {app_name}")
    
    def _search_web(self, query: str):
        """Search the web"""
        import webbrowser
        import urllib.parse
        
        search_url = f"https://www.google.com/search?q={urllib.parse.quote(query)}"
        webbrowser.open(search_url)
        self.text_queue.put(f"Searching for: {query}")


def load_config() -> VoiceConfig:
    """Load configuration from file"""
    config_file = CONFIG_DIR / "voice-assistant.conf"
    
    if config_file.exists():
        try:
            with open(config_file) as f:
                data = json.load(f)
            return VoiceConfig(**data)
        except (json.JSONDecodeError, TypeError) as e:
            logger.warning(f"Invalid config: {e}")
    
    return VoiceConfig()


def save_config(config: VoiceConfig):
    """Save configuration to file"""
    config_file = CONFIG_DIR / "voice-assistant.conf"
    config_file.parent.mkdir(parents=True, exist_ok=True)
    
    with open(config_file, 'w') as f:
        json.dump(config.__dict__, f, indent=2)


def main():
    parser = argparse.ArgumentParser(description="OrionOS Voice Assistant")
    parser.add_argument("--daemon", "-d", action="store_true",
                        help="Run as daemon")
    parser.add_argument("--config", "-c", type=str,
                        help="Configuration file path")
    parser.add_argument("--test", "-t", action="store_true",
                        help="Run in test mode")
    parser.add_argument("--calibrate", action="store_true",
                        help="Calibrate microphone")
    
    args = parser.parse_args()
    
    # Load configuration
    if args.config:
        config = VoiceConfig()
        with open(args.config) as f:
            data = json.load(f)
            config.__dict__.update(data)
    else:
        config = load_config()
    
    # Create data directory
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    
    # Initialize voice assistant
    assistant = VoiceAssistant(config)
    
    if args.test:
        logger.info("Running in test mode")
        # Test microphone
        assistant._test_microphone()
    elif args.calibrate:
        logger.info("Calibrating microphone")
        # Calibrate microphone
        assistant._calibrate_microphone()
    else:
        # Run voice assistant
        assistant.start()


if __name__ == "__main__":
    main()
