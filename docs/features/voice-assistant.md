# OrionOS Voice Assistant

## Overview
OrionOS Voice Assistant provides hands-free control of your system through voice commands. It supports speech-to-text (STT), text-to-speech (TTS), and wake word detection.

## Features
- **Speech-to-Text**: Whisper-based transcription
- **Text-to-Speech**: Piper neural TTS
- **Wake Word Detection**: OpenWakeWord integration
- **Voice Activity Detection**: WebRTC VAD
- **GPU Acceleration**: CUDA and ROCm support
- **Multi-Language**: Support for multiple languages

## Components

### Speech-to-Text (STT)
- **Engine**: OpenAI Whisper
- **Models**: tiny, base, small, medium, large
- **Languages**: 99+ languages
- **Acceleration**: CUDA, ROCm, CoreML

### Text-to-Speech (TTS)
- **Engine**: Piper
- **Voices**: Multiple neural voices
- **Quality**: High-quality neural synthesis
- **Speed**: Real-time on modern hardware

### Wake Word Detection
- **Engine**: OpenWakeWord
- **Custom Words**: Train your own wake words
- **Sensitivity**: Adjustable detection threshold

### Voice Activity Detection
- **Engine**: WebRTC VAD
- **Modes**: Aggressive, normal, relaxed
- **Noise Reduction**: Built-in noise suppression

## Usage

### Starting the Assistant
```bash
# Start voice assistant daemon
orionos-voice-assistant --daemon

# Or via systemd
systemctl --user start orionos-voice-assistant
```

### Voice Commands
Once activated (via wake word or button):
- "Open [application]"
- "Search for [query]"
- "What time is it?"
- "Take a note"
- "Play music"
- "Volume up/down"

### Configuration
```json
{
    "stt_model": "base",
    "stt_language": "en",
    "tts_voice": "en_US-lessac-medium",
    "wake_word_enabled": true,
    "wake_word": "hey orion",
    "vad_enabled": true,
    "gpu_enabled": true
}
```

## Installation

### System Requirements
- CPU: 4+ cores recommended
- RAM: 4GB minimum, 8GB recommended
- GPU: NVIDIA (CUDA) or AMD (ROCm) recommended
- Microphone: Working microphone required
- Speakers: Audio output required

### Package Installation
```bash
# Install voice assistant
sudo pacman -S orionos-voice-assistant

# Install dependencies
sudo pacman -S python-whisper python-piper python-webrtcvad
```

### GPU Setup
```bash
# For NVIDIA
sudo pacman -S nvidia-utils cuda

# For AMD
sudo pacman -S vulkan-radeon rocm-hip-runtime
```

## Development

### Building
```bash
make packages CORE=orionos-voice-assistant
```

### Architecture
- **Daemon**: Python-based service
- **STT Pipeline**: Audio capture → VAD → Whisper transcription
- **TTS Pipeline**: Text → Piper synthesis → Audio output
- **Wake Word**: Continuous monitoring → Detection → Activation

### Adding New Commands
To add new voice commands:
1. Add command handler in `src/commands/`
2. Register command in main module
3. Update documentation

## Troubleshooting

### No Audio Input
1. Check microphone permissions:
   ```bash
   arecord -l  # List audio devices
   ```
2. Verify PulseAudio/PipeWire:
   ```bash
   pactl list sources
   ```

### Slow Transcription
1. Check GPU acceleration:
   ```bash
   nvidia-smi  # For NVIDIA
   rocm-smi  # For AMD
   ```
2. Use smaller model:
   ```json
   {
       "stt_model": "tiny"
   }
   ```

### Wake Word Not Detecting
1. Adjust sensitivity:
   ```json
   {
       "wake_word_sensitivity": 0.3
   }
   ```
2. Check microphone quality
3. Reduce background noise

## References
- [Whisper Documentation](https://github.com/openai/whisper)
- [Piper Documentation](https://github.com/rhasspy/piper)
- [OpenWakeWord Documentation](https://github.com/dscripka/openWakeWord)
