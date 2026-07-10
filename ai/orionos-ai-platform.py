#!/usr/bin/env python3
"""
=============================================================================
OrionOS AI Platform
A unified local AI runtime supporting multiple backends and model families
=============================================================================

Architecture:
- Model Manager: Handles downloading, caching, and switching models
- Runtime Manager: Abstracts llama.cpp, Ollama, vLLM, ONNX, TensorRT-LLM, etc.
- API Server: OpenAI-compatible REST API for all models
- Voice Engine: STT/TTS with GPU acceleration
- OCR Engine: Document and image text extraction
- Plugin System: Extensible automation and integration framework
"""

import argparse
import asyncio
import hashlib
import json
import logging
import os
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional, Callable
import threading
import queue

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s'
)
logger = logging.getLogger('orionos-ai')


# =============================================================================
# Model Registry
# =============================================================================

class ModelFamily(Enum):
    QWEN = "qwen"
    LLAMA = "llama"
    MISTRAL = "mistral"
    DEEPSEEK = "deepseek"
    GEMMA = "gemma"
    PHI = "phi"
    GRANITE = "granite"
    GLM = "glm"
    AYA = "aya"
    FALCON = "falcon"


@dataclass
class ModelInfo:
    """Information about a downloadable model"""
    name: str
    family: ModelFamily
    size: str  # e.g., "7B", "14B", "70B"
    quant: str  # e.g., "Q4_K_M", "Q5_K_M", "Q8_0"
    url: str
    sha256: str
    context_length: int
    description: str
    tags: List[str] = field(default_factory=list)
    runtime_preference: List[str] = field(default_factory=list)


# Model Registry - Curated list of supported models
MODEL_REGISTRY: Dict[str, ModelInfo] = {
    # Qwen models (Primary recommendation)
    "qwen2.5-7b": ModelInfo(
        name="Qwen2.5-7B-Instruct",
        family=ModelFamily.QWEN,
        size="7B",
        quant="Q4_K_M",
        url="https://huggingface.co/Qwen/Qwen2.5-7B-Instruct-GGUF/resolve/main/qwen2.5-7b-instruct-q4_k_m.gguf",
        sha256="",
        context_length=32768,
        description="Alibaba's Qwen2.5 7B - Excellent multilingual and coding capabilities",
        tags=["chat", "coding", "multilingual", "recommended"],
        runtime_preference=["llama.cpp", "ollama", "vllm"]
    ),
    "qwen2.5-14b": ModelInfo(
        name="Qwen2.5-14B-Instruct",
        family=ModelFamily.QWEN,
        size="14B",
        quant="Q4_K_M",
        url="https://huggingface.co/Qwen/Qwen2.5-14B-Instruct-GGUF/resolve/main/qwen2.5-14b-instruct-q4_k_m.gguf",
        sha256="",
        context_length=32768,
        description="Qwen2.5 14B - Higher quality for complex tasks",
        tags=["chat", "coding", "multilingual"],
        runtime_preference=["llama.cpp", "ollama", "vllm"]
    ),

    # Llama models
    "llama-3.1-8b": ModelInfo(
        name="Llama-3.1-8B-Instruct",
        family=ModelFamily.LLAMA,
        size="8B",
        quant="Q4_K_M",
        url="https://huggingface.co/meta-llama/Llama-3.1-8B-Instruct-GGUF/resolve/main/llama-3.1-8b-instruct-q4_k_m.gguf",
        sha256="",
        context_length=128000,
        description="Meta's Llama 3.1 8B - Strong general-purpose model",
        tags=["chat", "general"],
        runtime_preference=["llama.cpp", "ollama", "vllm"]
    ),
    "llama-3.1-70b": ModelInfo(
        name="Llama-3.1-70B-Instruct",
        family=ModelFamily.LLAMA,
        size="70B",
        quant="Q4_K_M",
        url="https://huggingface.co/meta-llama/Llama-3.1-70B-Instruct-GGUF/resolve/main/llama-3.1-70b-instruct-q4_k_m.gguf",
        sha256="",
        context_length=128000,
        description="Llama 3.1 70B - High quality for demanding tasks",
        tags=["chat", "advanced"],
        runtime_preference=["vllm", "tensorrt-llm"]
    ),

    # Mistral models
    "mistral-7b-v0.3": ModelInfo(
        name="Mistral-7B-Instruct-v0.3",
        family=ModelFamily.MISTRAL,
        size="7B",
        quant="Q4_K_M",
        url="https://huggingface.co/mistralai/Mistral-7B-Instruct-v0.3-GGUF/resolve/main/mistral-7b-instruct-v0.3-q4_k_m.gguf",
        sha256="",
        context_length=32768,
        description="Mistral 7B v0.3 - Efficient and capable",
        tags=["chat", "efficient"],
        runtime_preference=["llama.cpp", "ollama", "vllm"]
    ),
    "mixtral-8x7b": ModelInfo(
        name="Mixtral-8x7B-Instruct-v0.1",
        family=ModelFamily.MISTRAL,
        size="47B",
        quant="Q4_K_M",
        url="https://huggingface.co/mistralai/Mixtral-8x7B-Instruct-v0.1-GGUF/resolve/main/mixtral-8x7b-instruct-v0.1-q4_k_m.gguf",
        sha256="",
        context_length=32768,
        description="Mixtral 8x7B - Sparse MoE architecture",
        tags=["chat", "moe", "advanced"],
        runtime_preference=["llama.cpp", "vllm"]
    ),

    # DeepSeek models
    "deepseek-llm-7b": ModelInfo(
        name="DeepSeek-LLM-7B-Chat",
        family=ModelFamily.DEEPSEEK,
        size="7B",
        quant="Q4_K_M",
        url="https://huggingface.co/deepseek-ai/deepseek-llm-7b-chat-GGUF/resolve/main/deepseek-llm-7b-chat-q4_k_m.gguf",
        sha256="",
        context_length=16384,
        description="DeepSeek 7B - Strong coding and reasoning",
        tags=["chat", "coding", "reasoning"],
        runtime_preference=["llama.cpp", "ollama", "vllm"]
    ),

    # Gemma models
    "gemma-2-9b": ModelInfo(
        name="Gemma-2-9B-IT",
        family=ModelFamily.GEMMA,
        size="9B",
        quant="Q4_K_M",
        url="https://huggingface.co/google/gemma-2-9b-it-GGUF/resolve/main/gemma-2-9b-it-q4_k_m.gguf",
        sha256="",
        context_length=8192,
        description="Google Gemma 2 9B - Lightweight and efficient",
        tags=["chat", "lightweight"],
        runtime_preference=["llama.cpp", "ollama"]
    ),

    # Phi models
    "phi-4-14b": ModelInfo(
        name="Phi-4-14B-Instruct",
        family=ModelFamily.PHI,
        size="14B",
        quant="Q4_K_M",
        url="https://huggingface.co/microsoft/phi-4-14b-instruct-GGUF/resolve/main/phi-4-14b-instruct-q4_k_m.gguf",
        sha256="",
        context_length=16384,
        description="Microsoft Phi-4 14B - Strong reasoning",
        tags=["chat", "reasoning"],
        runtime_preference=["llama.cpp", "ollama", "vllm"]
    ),

    # Granite models
    "granite-3.0-8b": ModelInfo(
        name="Granite-3.0-8B-Instruct",
        family=ModelFamily.GRANITE,
        size="8B",
        quant="Q4_K_M",
        url="https://huggingface.co/ibm-granite/granite-3.0-8b-instruct-GGUF/resolve/main/granite-3.0-8b-instruct-q4_k_m.gguf",
        sha256="",
        context_length=4096,
        description="IBM Granite 3.0 8B - Enterprise-focused",
        tags=["chat", "enterprise"],
        runtime_preference=["llama.cpp", "ollama"]
    ),

    # GLM models
    "glm-4-9b": ModelInfo(
        name="GLM-4-9B-Chat",
        family=ModelFamily.GLM,
        size="9B",
        quant="Q4_K_M",
        url="https://huggingface.co/THUDM/glm-4-9b-chat-GGUF/resolve/main/glm-4-9b-chat-q4_k_m.gguf",
        sha256="",
        context_length=128000,
        description="THUDM GLM-4 9B - Long context champion",
        tags=["chat", "long-context"],
        runtime_preference=["llama.cpp", "vllm"]
    ),

    # Aya models
    "aya-23-8b": ModelInfo(
        name="Aya-23-8B",
        family=ModelFamily.AYA,
        size="8B",
        quant="Q4_K_M",
        url="https://huggingface.co/CohereForAI/aya-23-8b-GGUF/resolve/main/aya-23-8b-q4_k_m.gguf",
        sha256="",
        context_length=8192,
        description="Cohere Aya 23 8B - Multilingual excellence",
        tags=["chat", "multilingual"],
        runtime_preference=["llama.cpp", "ollama"]
    ),

    # Falcon models
    "falcon-7b-instruct": ModelInfo(
        name="Falcon-7B-Instruct",
        family=ModelFamily.FALCON,
        size="7B",
        quant="Q4_K_M",
        url="https://huggingface.co/tiiuae/falcon-7b-instruct-GGUF/resolve/main/falcon-7b-instruct-q4_k_m.gguf",
        sha256="",
        context_length=2048,
        description="TII Falcon 7B - Efficient architecture",
        tags=["chat", "efficient"],
        runtime_preference=["llama.cpp", "ollama"]
    ),
}


# =============================================================================
# Runtime Backends
# =============================================================================

class RuntimeBackend(Enum):
    LLAMA_CPP = "llama.cpp"
    OLLAMA = "ollama"
    VLLM = "vllm"
    ONNX = "onnx"
    TENSORRT_LLM = "tensorrt-llm"
    OPENVINO = "openvino"
    ROCM = "rocm"


@dataclass
class RuntimeConfig:
    """Configuration for a runtime backend"""
    backend: RuntimeBackend
    executable: str
    gpu_layers: int = -1  # -1 = auto
    context_length: int = 4096
    batch_size: int = 512
    threads: int = -1  # -1 = auto
    port: int = 11434
    additional_args: Dict[str, Any] = field(default_factory=dict)


class RuntimeManager:
    """Manages AI runtime backends"""

    # Backend configurations
    BACKENDS: Dict[RuntimeBackend, RuntimeConfig] = {
        RuntimeBackend.LLAMA_CPP: RuntimeConfig(
            backend=RuntimeBackend.LLAMA_CPP,
            executable="llama-server",
            port=8080,
            additional_args={"--host": "127.0.0.1"}
        ),
        RuntimeBackend.OLLAMA: RuntimeConfig(
            backend=RuntimeBackend.OLLAMA,
            executable="ollama",
            port=11434,
            additional_args={}
        ),
        RuntimeBackend.VLLM: RuntimeConfig(
            backend=RuntimeBackend.VLLM,
            executable="python -m vllm.entrypoints.openai.api_server",
            port=8000,
            additional_args={"--host": "127.0.0.1"}
        ),
        RuntimeBackend.ONNX: RuntimeConfig(
            backend=RuntimeBackend.ONNX,
            executable="ort-server",
            port=8001,
            additional_args={}
        ),
    }

    def __init__(self, models_dir: Path):
        self.models_dir = models_dir
        self.active_processes: Dict[RuntimeBackend, subprocess.Popen] = {}
        self._lock = threading.Lock()

    def detect_gpu(self) -> Dict[str, Any]:
        """Detect available GPU hardware"""
        gpu_info = {
            "available": False,
            "vendor": None,
            "vram_mb": 0,
            "cuda": False,
            "rocm": False,
            "vulkan": False,
        }

        # Check NVIDIA
        try:
            result = subprocess.run(
                ["nvidia-smi", "--query-gpu=name,memory.total", "--format=csv,noheader"],
                capture_output=True, text=True, timeout=5
            )
            if result.returncode == 0:
                parts = result.stdout.strip().split(',')
                if len(parts) >= 2:
                    vram_str = parts[1].strip().replace(' MiB', '')
                    gpu_info["available"] = True
                    gpu_info["vendor"] = "nvidia"
                    gpu_info["vram_mb"] = int(vram_str)
                    gpu_info["cuda"] = True
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass

        # Check AMD
        if not gpu_info["available"]:
            try:
                if Path("/sys/class/kfd/kfd/topology/nodes").exists():
                    gpu_info["available"] = True
                    gpu_info["vendor"] = "amd"
                    gpu_info["rocm"] = True
                    # Try to get VRAM
                    result = subprocess.run(
                        ["rocminfo"], capture_output=True, text=True, timeout=5
                    )
                    if result.returncode == 0:
                        for line in result.stdout.split('\n'):
                            if 'Pool 1' in line and 'size:' in line:
                                vram_str = line.split('size:')[1].strip().split()[0]
                                gpu_info["vram_mb"] = int(vram_str) // (1024 * 1024)
            except (subprocess.TimeoutExpired, FileNotFoundError):
                pass

        # Check Intel
        if not gpu_info["available"]:
            try:
                result = subprocess.run(
                    ["intel_gpu_top", "-L"], capture_output=True, text=True, timeout=2
                )
                if result.returncode == 0 or "render" in result.stdout:
                    gpu_info["available"] = True
                    gpu_info["vendor"] = "intel"
            except (subprocess.TimeoutExpired, FileNotFoundError):
                pass

        return gpu_info

    def get_optimal_backend(self, model: ModelInfo) -> RuntimeBackend:
        """Determine the best backend for a given model and hardware"""
        gpu = self.detect_gpu()

        for runtime_name in model.runtime_preference:
            try:
                backend = RuntimeBackend(runtime_name)
                # Check if executable exists
                config = self.BACKENDS.get(backend)
                if config:
                    if shutil.which(config.executable.split()[0]):
                        # vLLM and TensorRT need NVIDIA
                        if backend in (RuntimeBackend.VLLM, RuntimeBackend.TENSORRT_LLM) and not gpu["cuda"]:
                            continue
                        return backend
            except ValueError:
                continue

        # Fallback to llama.cpp (most compatible)
        return RuntimeBackend.LLAMA_CPP

    def start_server(self, model: ModelInfo, backend: Optional[RuntimeBackend] = None) -> bool:
        """Start a model server with the specified backend"""
        if backend is None:
            backend = self.get_optimal_backend(model)

        config = self.BACKENDS.get(backend)
        if not config:
            logger.error(f"Unknown backend: {backend}")
            return False

        with self._lock:
            # Stop any existing server on this backend
            if backend in self.active_processes:
                self.stop_server(backend)

            model_path = self.models_dir / f"{model.name.lower().replace(' ', '-')}.gguf"

            if not model_path.exists():
                logger.error(f"Model not found: {model_path}")
                return False

            # Build command
            cmd = self._build_command(backend, config, model_path)
            logger.info(f"Starting {backend.value} server for {model.name}")
            logger.debug(f"Command: {' '.join(cmd)}")

            try:
                process = subprocess.Popen(
                    cmd,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True
                )
                self.active_processes[backend] = process

                # Wait a moment to check if it started successfully
                time.sleep(2)
                if process.poll() is not None:
                    stdout, stderr = process.communicate()
                    logger.error(f"Server failed to start: {stderr}")
                    return False

                logger.info(f"Server started on port {config.port}")
                return True

            except Exception as e:
                logger.error(f"Failed to start server: {e}")
                return False

    def _build_command(self, backend: RuntimeBackend, config: RuntimeConfig, model_path: Path) -> List[str]:
        """Build the command line for a backend"""
        gpu = self.detect_gpu()
        gpu_layers = config.gpu_layers
        if gpu_layers == -1 and gpu["available"]:
            # Auto-determine GPU layers based on VRAM
            vram_gb = gpu["vram_mb"] / 1024
            if vram_gb >= 24:
                gpu_layers = 999  # All layers
            elif vram_gb >= 16:
                gpu_layers = 35
            elif vram_gb >= 12:
                gpu_layers = 25
            elif vram_gb >= 8:
                gpu_layers = 20
            elif vram_gb >= 6:
                gpu_layers = 15
            else:
                gpu_layers = 10

        if backend == RuntimeBackend.LLAMA_CPP:
            cmd = [
                config.executable,
                "-m", str(model_path),
                "--host", "127.0.0.1",
                "--port", str(config.port),
                "-c", str(config.context_length),
                "-n", str(config.threads if config.threads > 0 else os.cpu_count() or 4),
            ]
            if gpu["available"] and gpu_layers > 0:
                cmd.extend(["-ngl", str(gpu_layers)])
                if gpu["vendor"] == "nvidia":
                    cmd.extend(["--flash-attn"])
            cmd.extend([f"{k}={v}" for k, v in config.additional_args.items() if not k.startswith('--')])
            return cmd

        elif backend == RuntimeBackend.OLLAMA:
            # Ollama uses its own model management
            model_name = model_path.stem
            return [
                config.executable,
                "serve"
            ]

        elif backend == RuntimeBackend.VLLM:
            return [
                "python", "-m", "vllm.entrypoints.openai.api_server",
                "--model", str(model_path),
                "--host", "127.0.0.1",
                "--port", str(config.port),
                "--gpu-memory-utilization", "0.9",
            ]

        return [config.executable]

    def stop_server(self, backend: RuntimeBackend) -> None:
        """Stop a running server"""
        with self._lock:
            if backend in self.active_processes:
                process = self.active_processes[backend]
                logger.info(f"Stopping {backend.value} server")
                process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
                del self.active_processes[backend]

    def stop_all(self) -> None:
        """Stop all running servers"""
        with self._lock:
            for backend in list(self.active_processes.keys()):
                self.stop_server(backend)


# =============================================================================
# Model Manager
# =============================================================================

class ModelManager:
    """Manages AI model downloads, caching, and metadata"""

    def __init__(self, models_dir: Path, cache_dir: Path):
        self.models_dir = models_dir
        self.cache_dir = cache_dir
        self.models_dir.mkdir(parents=True, exist_ok=True)
        self.cache_dir.mkdir(parents=True, exist_ok=True)

    def list_available(self, filter_tag: Optional[str] = None) -> List[ModelInfo]:
        """List available models, optionally filtered by tag"""
        models = list(MODEL_REGISTRY.values())
        if filter_tag:
            models = [m for m in models if filter_tag in m.tags]
        return models

    def list_installed(self) -> List[Dict[str, Any]]:
        """List installed models with metadata"""
        installed = []
        for model_file in self.models_dir.glob("*.gguf"):
            stat = model_file.stat()
            size_gb = stat.st_size / (1024**3)
            installed.append({
                "name": model_file.stem,
                "path": str(model_file),
                "size_gb": round(size_gb, 2),
                "modified": stat.st_mtime,
            })
        return installed

    def is_installed(self, model_key: str) -> bool:
        """Check if a model is installed"""
        model = MODEL_REGISTRY.get(model_key)
        if not model:
            return False
        model_path = self.models_dir / f"{model.name.lower().replace(' ', '-')}.gguf"
        return model_path.exists()

    def download(self, model_key: str, progress_callback: Optional[Callable] = None) -> bool:
        """Download a model from the registry"""
        model = MODEL_REGISTRY.get(model_key)
        if not model:
            logger.error(f"Unknown model: {model_key}")
            return False

        model_path = self.models_dir / f"{model.name.lower().replace(' ', '-')}.gguf"

        if model_path.exists():
            logger.info(f"Model {model.name} already exists")
            return True

        logger.info(f"Downloading {model.name}...")
        logger.info(f"URL: {model.url}")

        try:
            import urllib.request
            import urllib.error

            def report_progress(block_num, block_size, total_size):
                downloaded = block_num * block_size
                percent = min(downloaded * 100 / total_size, 100)
                if progress_callback:
                    progress_callback(percent, downloaded, total_size)
                else:
                    sys.stdout.write(f"\r  Progress: {percent:.1f}%")
                    sys.stdout.flush()

            model_path.parent.mkdir(parents=True, exist_ok=True)
            urllib.request.urlretrieve(
                model.url,
                str(model_path) + ".tmp",
                reporthook=report_progress
            )
            print()  # New line after progress

            # Move to final location
            shutil.move(str(model_path) + ".tmp", str(model_path))

            logger.info(f"Download complete: {model_path}")
            logger.info(f"Size: {model_path.stat().st_size / (1024**3):.2f} GB")
            return True

        except Exception as e:
            logger.error(f"Download failed: {e}")
            # Clean up partial download
            tmp_path = Path(str(model_path) + ".tmp")
            if tmp_path.exists():
                tmp_path.unlink()
            return False

    def remove(self, model_key: str) -> bool:
        """Remove an installed model"""
        model = MODEL_REGISTRY.get(model_key)
        if not model:
            logger.error(f"Unknown model: {model_key}")
            return False

        model_path = self.models_dir / f"{model.name.lower().replace(' ', '-')}.gguf"

        if not model_path.exists():
            logger.warning(f"Model not found: {model_path}")
            return False

        model_path.unlink()
        logger.info(f"Removed: {model.name}")
        return True

    def get_model_info(self, model_key: str) -> Optional[Dict[str, Any]]:
        """Get detailed information about a model"""
        model = MODEL_REGISTRY.get(model_key)
        if not model:
            return None

        return {
            "key": model_key,
            "name": model.name,
            "family": model.family.value,
            "size": model.size,
            "quantization": model.quant,
            "context_length": model.context_length,
            "description": model.description,
            "tags": model.tags,
            "installed": self.is_installed(model_key),
            "runtime_preference": model.runtime_preference,
        }


# =============================================================================
# Voice Engine (STT/TTS)
# =============================================================================

class VoiceEngine:
    """Speech-to-text and text-to-speech engine"""

    def __init__(self, models_dir: Path):
        self.models_dir = models_dir
        self.stt_model = None
        self.tts_model = None
        self._initialized = False

    def initialize(self):
        """Initialize voice models"""
        if self._initialized:
            return

        logger.info("Initializing voice engine...")

        # Try to load faster-whisper for STT
        try:
            from faster_whisper import WhisperModel
            stt_path = self.models_dir / "stt" / "faster-whisper-medium"
            if stt_path.exists():
                self.stt_model = WhisperModel(
                    str(stt_path),
                    device="cuda" if self._check_cuda() else "cpu",
                    compute_type="float16" if self._check_cuda() else "int8"
                )
                logger.info("STT model loaded")
        except ImportError:
            logger.warning("faster-whisper not available for STT")

        # Try to load Piper for TTS
        try:
            import piper
            tts_path = self.models_dir / "tts" / "piper-voice.onnx"
            if tts_path.exists():
                # Initialize Piper TTS
                self.tts_model = str(tts_path)
                logger.info("TTS model loaded")
        except ImportError:
            logger.warning("piper-tts not available for TTS")

        self._initialized = True

    def _check_cuda(self) -> bool:
        """Check if CUDA is available"""
        try:
            import torch
            return torch.cuda.is_available()
        except ImportError:
            return False

    def speech_to_text(self, audio_path: str, language: str = "auto") -> str:
        """Convert speech to text"""
        self.initialize()

        if not self.stt_model:
            raise RuntimeError("STT model not available")

        segments, info = self.stt_model.transcribe(
            audio_path,
            language=language if language != "auto" else None,
            task="transcribe"
        )

        text = " ".join([segment.text for segment in segments])
        return text.strip()

    def text_to_speech(self, text: str, output_path: str, speaker_id: Optional[int] = None) -> None:
        """Convert text to speech"""
        self.initialize()

        if not self.tts_model:
            raise RuntimeError("TTS model not available")

        # Use Piper for TTS
        import subprocess
        cmd = [
            "piper",
            "--model", self.tts_model,
            "--output_file", output_path,
        ]
        if speaker_id is not None:
            cmd.extend(["--speaker", str(speaker_id)])

        process = subprocess.Popen(
            cmd,
            stdin=subprocess.PIPE,
            text=True
        )
        process.communicate(input=text)


# =============================================================================
# OCR Engine
# =============================================================================

class OCREngine:
    """Optical Character Recognition engine"""

    def __init__(self):
        self._processor = None
        self._model = None
        self._initialized = False

    def initialize(self):
        """Initialize OCR models"""
        if self._initialized:
            return

        try:
            from transformers import TrOCRProcessor, VisionEncoderDecoderModel
            import torch

            self._processor = TrOCRProcessor.from_pretrained("microsoft/trocr-base-printed")
            self._model = VisionEncoderDecoderModel.from_pretrained("microsoft/trocr-base-printed")

            if torch.cuda.is_available():
                self._model = self._model.cuda()

            self._initialized = True
            logger.info("OCR engine initialized")

        except ImportError:
            logger.warning("transformers not available for OCR")
        except Exception as e:
            logger.error(f"OCR initialization failed: {e}")

    def extract_text(self, image_path: str) -> str:
        """Extract text from an image"""
        self.initialize()

        if not self._model:
            raise RuntimeError("OCR model not available")

        from PIL import Image
        import torch

        image = Image.open(image_path).convert("RGB")
        pixel_values = self._processor(image, return_tensors="pt").pixel_values

        if torch.cuda.is_available():
            pixel_values = pixel_values.cuda()

        generated_ids = self._model.generate(pixel_values)
        generated_text = self._processor.batch_decode(generated_ids, skip_special_tokens=True)[0]

        return generated_text.strip()


# =============================================================================
# Plugin System
# =============================================================================

class PluginManager:
    """Extensible plugin architecture for AI automation"""

    def __init__(self, plugins_dir: Path):
        self.plugins_dir = plugins_dir
        self.plugins_dir.mkdir(parents=True, exist_ok=True)
        self._plugins: Dict[str, Any] = {}
        self._hooks: Dict[str, List[Callable]] = {}

    def discover(self) -> List[str]:
        """Discover available plugins"""
        plugins = []
        for plugin_file in self.plugins_dir.glob("*.py"):
            plugins.append(plugin_file.stem)
        return plugins

    def load(self, name: str) -> bool:
        """Load a plugin by name"""
        plugin_path = self.plugins_dir / f"{name}.py"
        if not plugin_path.exists():
            logger.error(f"Plugin not found: {name}")
            return False

        try:
            import importlib.util
            spec = importlib.util.spec_from_file_location(name, plugin_path)
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)

            if hasattr(module, 'OrionOSPlugin'):
                plugin = module.OrionOSPlugin()
                self._plugins[name] = plugin
                plugin.register(self)
                logger.info(f"Plugin loaded: {name}")
                return True
            else:
                logger.error(f"Plugin {name} missing OrionOSPlugin class")
                return False

        except Exception as e:
            logger.error(f"Failed to load plugin {name}: {e}")
            return False

    def unload(self, name: str) -> None:
        """Unload a plugin"""
        if name in self._plugins:
            plugin = self._plugins[name]
            if hasattr(plugin, 'cleanup'):
                plugin.cleanup()
            del self._plugins[name]
            logger.info(f"Plugin unloaded: {name}")

    def register_hook(self, event: str, callback: Callable) -> None:
        """Register a hook for an event"""
        if event not in self._hooks:
            self._hooks[event] = []
        self._hooks[event].append(callback)

    def trigger_hook(self, event: str, *args, **kwargs) -> List[Any]:
        """Trigger all hooks for an event"""
        results = []
        for callback in self._hooks.get(event, []):
            try:
                result = callback(*args, **kwargs)
                results.append(result)
            except Exception as e:
                logger.error(f"Hook error in {event}: {e}")
        return results

    def list_plugins(self) -> List[Dict[str, Any]]:
        """List loaded plugins with info"""
        return [
            {
                "name": name,
                "version": getattr(plugin, 'version', 'unknown'),
                "description": getattr(plugin, 'description', ''),
            }
            for name, plugin in self._plugins.items()
        ]


# =============================================================================
# Main CLI
# =============================================================================

def main():
    parser = argparse.ArgumentParser(
        description='OrionOS AI Platform - Local AI runtime and model management',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  orionos-ai list                          List all available models
  orionos-ai list --installed              List installed models
  orionos-ai list --tag coding             Filter by tag
  orionos-ai info qwen2.5-7b               Show model details
  orionos-ai download qwen2.5-7b           Download a model
  orionos-ai remove qwen2.5-7b             Remove a model
  orionos-ai serve qwen2.5-7b              Start model server
  orionos-ai serve qwen2.5-7b --backend vllm   Use specific backend
  orionos-ai stop                          Stop all servers
  orionos-ai chat qwen2.5-7b               Interactive chat
  orionos-ai stt audio.wav                 Speech to text
  orionos-ai tts "Hello" output.wav        Text to speech
  orionos-ai ocr image.png                 OCR text extraction
  orionos-ai plugins                       List plugins
  orionos-ai plugins --load myplugin       Load a plugin
        """
    )

    parser.add_argument('--models-dir', default='/var/lib/orionos/ai/models',
                       help='Models directory')
    parser.add_argument('--cache-dir', default='/var/cache/orionos/ai',
                       help='Cache directory')
    parser.add_argument('--verbose', '-v', action='store_true',
                       help='Verbose output')

    subparsers = parser.add_subparsers(dest='command', help='Commands')

    # List command
    list_parser = subparsers.add_parser('list', help='List models')
    list_parser.add_argument('--installed', action='store_true',
                            help='List only installed models')
    list_parser.add_argument('--tag', help='Filter by tag')

    # Info command
    info_parser = subparsers.add_parser('info', help='Show model info')
    info_parser.add_argument('model', help='Model key')

    # Download command
    download_parser = subparsers.add_parser('download', help='Download a model')
    download_parser.add_argument('model', help='Model key')

    # Remove command
    remove_parser = subparsers.add_parser('remove', help='Remove a model')
    remove_parser.add_argument('model', help='Model key')

    # Serve command
    serve_parser = subparsers.add_parser('serve', help='Start model server')
    serve_parser.add_argument('model', help='Model key')
    serve_parser.add_argument('--backend', choices=[b.value for b in RuntimeBackend],
                             help='Runtime backend')
    serve_parser.add_argument('--port', type=int, help='Server port')

    # Stop command
    subparsers.add_parser('stop', help='Stop all servers')

    # Chat command
    chat_parser = subparsers.add_parser('chat', help='Interactive chat')
    chat_parser.add_argument('model', help='Model key')
    chat_parser.add_argument('--system', help='System prompt')

    # STT command
    stt_parser = subparsers.add_parser('stt', help='Speech to text')
    stt_parser.add_argument('audio', help='Audio file path')
    stt_parser.add_argument('--language', default='auto', help='Language code')

    # TTS command
    tts_parser = subparsers.add_parser('tts', help='Text to speech')
    tts_parser.add_argument('text', help='Text to convert')
    tts_parser.add_argument('output', help='Output audio file')

    # OCR command
    ocr_parser = subparsers.add_parser('ocr', help='OCR text extraction')
    ocr_parser.add_argument('image', help='Image file path')

    # Plugins command
    plugins_parser = subparsers.add_parser('plugins', help='Plugin management')
    plugins_parser.add_argument('--load', help='Load a plugin')
    plugins_parser.add_argument('--unload', help='Unload a plugin')

    # GPU info
    subparsers.add_parser('gpu', help='Show GPU information')

    args = parser.parse_args()

    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    models_dir = Path(args.models_dir)
    cache_dir = Path(args.cache_dir)

    model_manager = ModelManager(models_dir, cache_dir)
    runtime_manager = RuntimeManager(models_dir)

    if args.command == 'list':
        if args.installed:
            print("\nInstalled Models:")
            print("-" * 60)
            for model in model_manager.list_installed():
                print(f"  {model['name']} ({model['size_gb']} GB)")
        else:
            print("\nAvailable Models:")
            print("-" * 60)
            for model in model_manager.list_available(args.tag):
                installed = "✓" if model_manager.is_installed(
                    [k for k, v in MODEL_REGISTRY.items() if v == model][0]
                ) else " "
                print(f" [{installed}] {model.name}")
                print(f"     Family: {model.family.value} | Size: {model.size} | Quant: {model.quant}")
                print(f"     Context: {model.context_length} | Tags: {', '.join(model.tags)}")
                print()

    elif args.command == 'info':
        info = model_manager.get_model_info(args.model)
        if info:
            print(json.dumps(info, indent=2))
        else:
            print(f"Model not found: {args.model}")
            sys.exit(1)

    elif args.command == 'download':
        def progress(percent, downloaded, total):
            mb = downloaded / (1024 * 1024)
            total_mb = total / (1024 * 1024)
            sys.stdout.write(f"\r  {percent:.1f}% ({mb:.1f}/{total_mb:.1f} MB)")
            sys.stdout.flush()

        success = model_manager.download(args.model, progress)
        sys.exit(0 if success else 1)

    elif args.command == 'remove':
        success = model_manager.remove(args.model)
        sys.exit(0 if success else 1)

    elif args.command == 'serve':
        model = MODEL_REGISTRY.get(args.model)
        if not model:
            print(f"Model not found: {args.model}")
            sys.exit(1)

        if not model_manager.is_installed(args.model):
            print(f"Model not installed: {args.model}")
            print(f"Run: orionos-ai download {args.model}")
            sys.exit(1)

        backend = None
        if args.backend:
            backend = RuntimeBackend(args.backend)

        try:
            if runtime_manager.start_server(model, backend):
                print(f"Server started. Press Ctrl+C to stop.")
                while True:
                    time.sleep(1)
        except KeyboardInterrupt:
            print("\nStopping server...")
            runtime_manager.stop_all()

    elif args.command == 'stop':
        runtime_manager.stop_all()
        print("All servers stopped.")

    elif args.command == 'chat':
        model = MODEL_REGISTRY.get(args.model)
        if not model:
            print(f"Model not found: {args.model}")
            sys.exit(1)

        # Simple interactive chat using curl to the API
        backend = runtime_manager.get_optimal_backend(model)
        config = runtime_manager.BACKENDS.get(backend)
        port = args.port or (config.port if config else 8080)

        print(f"OrionOS AI Chat - {model.name}")
        print("Type 'exit' to quit, '/help' for commands")
        print("-" * 40)

        system_prompt = args.system or "You are a helpful AI assistant."
        messages = [{"role": "system", "content": system_prompt}]

        while True:
            try:
                user_input = input("\nYou: ").strip()
                if not user_input:
                    continue
                if user_input.lower() == 'exit':
                    break
                if user_input == '/help':
                    print("Commands: /help, /clear, /system <prompt>, exit")
                    continue
                if user_input == '/clear':
                    messages = [{"role": "system", "content": system_prompt}]
                    print("Chat history cleared.")
                    continue
                if user_input.startswith('/system '):
                    system_prompt = user_input[8:]
                    messages[0]["content"] = system_prompt
                    print(f"System prompt updated.")
                    continue

                messages.append({"role": "user", "content": user_input})

                # Make API request
                import urllib.request
                import urllib.error

                request_data = json.dumps({
                    "messages": messages,
                    "stream": False,
                    "temperature": 0.7,
                    "max_tokens": 2048,
                }).encode()

                req = urllib.request.Request(
                    f"http://127.0.0.1:{port}/v1/chat/completions",
                    data=request_data,
                    headers={"Content-Type": "application/json"},
                    method='POST'
                )

                try:
                    with urllib.request.urlopen(req, timeout=120) as response:
                        result = json.loads(response.read().decode())
                        assistant_msg = result['choices'][0]['message']['content']
                        print(f"\nAI: {assistant_msg}")
                        messages.append({"role": "assistant", "content": assistant_msg})
                except urllib.error.URLError:
                    print("Error: Could not connect to AI server.")
                    print(f"Make sure the server is running: orionos-ai serve {args.model}")

            except (EOFError, KeyboardInterrupt):
                break

        print("\nGoodbye!")

    elif args.command == 'stt':
        voice = VoiceEngine(models_dir)
        try:
            text = voice.speech_to_text(args.audio, args.language)
            print(f"Transcription: {text}")
        except Exception as e:
            print(f"STT Error: {e}")
            sys.exit(1)

    elif args.command == 'tts':
        voice = VoiceEngine(models_dir)
        try:
            voice.text_to_speech(args.text, args.output)
            print(f"Audio saved: {args.output}")
        except Exception as e:
            print(f"TTS Error: {e}")
            sys.exit(1)

    elif args.command == 'ocr':
        ocr = OCREngine()
        try:
            text = ocr.extract_text(args.image)
            print(f"Extracted text: {text}")
        except Exception as e:
            print(f"OCR Error: {e}")
            sys.exit(1)

    elif args.command == 'plugins':
        plugins_dir = Path("/usr/share/orionos/ai/plugins")
        plugin_manager = PluginManager(plugins_dir)

        if args.load:
            plugin_manager.load(args.load)
        elif args.unload:
            plugin_manager.unload(args.unload)
        else:
            print("\nAvailable plugins:")
            for name in plugin_manager.discover():
                loaded = "✓" if name in plugin_manager._plugins else " "
                print(f"  [{loaded}] {name}")

    elif args.command == 'gpu':
        gpu_info = runtime_manager.detect_gpu()
        print(json.dumps(gpu_info, indent=2))

    else:
        parser.print_help()


if __name__ == '__main__':
    main()
