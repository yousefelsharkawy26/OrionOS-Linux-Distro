#!/usr/bin/env python3
"""
OrionOS AI Model Marketplace
Download, manage, and deploy AI models from multiple sources.
"""

import os
import sys
import json
import shutil
import logging
import hashlib
import argparse
import subprocess
from pathlib import Path
from typing import Optional, Dict, List
from dataclasses import dataclass, asdict
from datetime import datetime

try:
    import requests
except ImportError:
    requests = None

CONFIG_DIR = Path("/etc/orionos")
MODEL_DIR = Path("/var/lib/orionos/ai-models")
CACHE_DIR = Path("/var/cache/orionos/ai-marketplace")
LOG_DIR = Path("/var/log/orio nos")

LOG_DIR.mkdir(parents=True, exist_ok=True)
MODEL_DIR.mkdir(parents=True, exist_ok=True)
CACHE_DIR.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.FileHandler(LOG_DIR / "ai-marketplace.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("orionos-ai-marketplace")


@dataclass
class AIModel:
    id: str
    name: str
    version: str
    description: str
    author: str
    framework: str  # ollama, llama.cpp, onnx, pytorch, tensorflow
    license: str
    size_gb: float
    parameters: str  # e.g. "7B", "13B", "70B"
    quantization: str  # f16, q8_0, q4_0, q4_k_m
    tags: List[str]
    downloads: int
    rating: float
    verified: bool
    source: str  # ollama, huggingface, ollama-library
    model_url: str
    min_ram_gb: int
    gpu_required: bool
    gpu_memory_gb: int
    benchmark: Dict[str, float]


@dataclass
class InstalledModel:
    model_id: str
    version: str
    installed_at: str
    path: str
    size_gb: float
    backend: str
    enabled: bool
    config: Dict[str, any]


@dataclass
class MarketplaceConfig:
    sources: List[Dict[str, str]] = None
    auto_update: bool = True
    max_cache_size_gb: int = 50
    default_backend: str = "ollama"
    gpu_offload_layers: int = 32
    context_length: int = 4096
    temperature: float = 0.7
    model_dir: str = str(MODEL_DIR)

    def __post_init__(self):
        if self.sources is None:
            self.sources = [
                {"name": "ollama-library", "url": "https://ollama.ai/library", "type": "ollama"},
                {"name": "huggingface", "url": "https://huggingface.co/api/models", "type": "huggingface"},
                {"name": "orionos-hub", "url": "https://models.orionos.org/api/v1", "type": "registry"},
            ]


MODEL_CATALOG = [
    AIModel(
        id="llama-3.1-8b", name="LLaMA 3.1 8B", version="3.1",
        description="Meta's LLaMA 3.1 8B - fast, efficient general-purpose model",
        author="Meta", framework="ollama", license="llama3.1", size_gb=4.7,
        parameters="8B", quantization="q4_0", tags=["general", "chat", "fast"],
        downloads=5000000, rating=4.8, verified=True, source="ollama-library",
        model_url="ollama://llama3.1", min_ram_gb=8, gpu_required=False,
        gpu_memory_gb=6, benchmark={"mmlu": 68.4, "humaneval": 61.0}
    ),
    AIModel(
        id="llama-3.1-70b", name="LLaMA 3.1 70B", version="3.1",
        description="Meta's LLaMA 3.1 70B - state-of-the-art reasoning",
        author="Meta", framework="ollama", license="llama3.1", size_gb=40.0,
        parameters="70B", quantization="q4_0", tags=["reasoning", "coding", "advanced"],
        downloads=1000000, rating=4.9, verified=True, source="ollama-library",
        model_url="ollama://llama3.1:70b", min_ram_gb=48, gpu_required=True,
        gpu_memory_gb=40, benchmark={"mmlu": 83.6, "humaneval": 80.5}
    ),
    AIModel(
        id="qwen-2.5-72b", name="Qwen 2.5 72B", version="2.5",
        description="Alibaba's Qwen 2.5 72B - multilingual powerhouse",
        author="Alibaba", framework="ollama", license="apache-2.0", size_gb=42.0,
        parameters="72B", quantization="q4_k_m", tags=["multilingual", "coding", "reasoning"],
        downloads=800000, rating=4.8, verified=True, source="ollama-library",
        model_url="ollama://qwen2.5:72b", min_ram_gb=48, gpu_required=True,
        gpu_memory_gb=42, benchmark={"mmlu": 85.3, "humaneval": 84.2}
    ),
    AIModel(
        id="mistral-large", name="Mistral Large 2", version="2",
        description="Mistral AI's Large 2 - excellent multilingual and reasoning",
        author="Mistral AI", framework="ollama", license="apache-2.0", size_gb=40.0,
        parameters="123B", quantization="q4_0", tags=["reasoning", "multilingual", "advanced"],
        downloads=500000, rating=4.7, verified=True, source="ollama-library",
        model_url="ollama://mistral-large", min_ram_gb=64, gpu_required=True,
        gpu_memory_gb=50, benchmark={"mmlu": 84.0, "humaneval": 79.0}
    ),
    AIModel(
        id="deepseek-coder-33b", name="DeepSeek Coder 33B", version="2",
        description="DeepSeek Coder 33B - specialist in code generation",
        author="DeepSeek", framework="ollama", license="deepseek", size_gb=18.0,
        parameters="33B", quantization="q4_k_m", tags=["coding", "programming", "specialized"],
        downloads=600000, rating=4.7, verified=True, source="ollama-library",
        model_url="ollama://deepseek-coder:33b", min_ram_gb=24, gpu_required=True,
        gpu_memory_gb=20, benchmark={"mmlu": 65.0, "humaneval": 90.2}
    ),
    AIModel(
        id="phi-3.5-mini", name="Phi-3.5 Mini", version="3.5",
        description="Microsoft Phi-3.5 Mini - small but mighty",
        author="Microsoft", framework="ollama", license="mit", size_gb=2.2,
        parameters="3.8B", quantization="q4_0", tags=["small", "fast", "efficient"],
        downloads=1200000, rating=4.5, verified=True, source="ollama-library",
        model_url="ollama://phi3.5", min_ram_gb=4, gpu_required=False,
        gpu_memory_gb=2, benchmark={"mmlu": 69.0, "humaneval": 58.0}
    ),
    AIModel(
        id="gemma-2-27b", name="Gemma 2 27B", version="2",
        description="Google's Gemma 2 27B - balanced performance",
        author="Google", framework="ollama", license="gemma", size_gb=16.0,
        parameters="27B", quantization="q4_k_m", tags=["general", "balanced", "chat"],
        downloads=700000, rating=4.6, verified=True, source="ollana-library",
        model_url="ollama://gemma2:27b", min_ram_gb=20, gpu_required=True,
        gpu_memory_gb=16, benchmark={"mmlu": 75.2, "humaneval": 72.0}
    ),
    AIModel(
        id="codellama-34b", name="Code Llama 34B", version="1",
        description="Meta's Code Llama - specialized for code generation",
        author="Meta", framework="ollama", license="llama2", size_gb=19.0,
        parameters="34B", quantization="q4_k_m", tags=["coding", "programming", "specialized"],
        downloads=400000, rating=4.5, verified=True, source="ollama-library",
        model_url="ollama://codellama:34b", min_ram_gb=24, gpu_required=True,
        gpu_memory_gb=20, benchmark={"mmlu": 60.0, "humaneval": 88.0}
    ),
    AIModel(
        id="whisper-large-v3", name="Whisper Large V3", version="3",
        description="OpenAI Whisper Large V3 - state-of-the-art speech recognition",
        author="OpenAI", framework="onnx", license="mit", size_gb=3.0,
        parameters="1.5B", quantization="f16", tags=["speech", "transcription", "audio"],
        downloads=2000000, rating=4.9, verified=True, source="huggingface",
        model_url="huggingface://openai/whisper-large-v3", min_ram_gb=4, gpu_required=False,
        gpu_memory_gb=3, benchmark={"wer": 4.2}
    ),
    AIModel(
        id="stable-diffusion-xl", name="Stable Diffusion XL", version="1.0",
        description="Stability AI's SDXL - image generation",
        author="Stability AI", framework="onnx", license="openrail", size_gb=6.5,
        parameters="2.6B", quantization="f16", tags=["image", "generation", "creative"],
        downloads=3000000, rating=4.8, verified=True, source="huggingface",
        model_url="huggingface://stabilityai/stable-diffusion-xl-base-1.0",
        min_ram_gb=8, gpu_required=True, gpu_memory_gb=8,
        benchmark={"fid": 23.0}
    ),
]


class AIModelMarketplace:
    def __init__(self, config: MarketplaceConfig):
        self.config = config
        self.installed_file = MODEL_DIR / "installed.json"
        self.installed: Dict[str, InstalledModel] = {}
        self._load_installed()

    def _load_installed(self):
        if self.installed_file.exists():
            with open(self.installed_file) as f:
                data = json.load(f)
                for mid, mdata in data.items():
                    self.installed[mid] = InstalledModel(**mdata)

    def _save_installed(self):
        with open(self.installed_file, 'w') as f:
            json.dump({mid: asdict(m) for mid, m in self.installed.items()}, f, indent=2)

    def search(self, query: str = "", tag: str = "", framework: str = "") -> List[AIModel]:
        results = MODEL_CATALOG
        if query:
            q = query.lower()
            results = [m for m in results if q in m.name.lower() or q in m.description.lower() or q in m.id.lower()]
        if tag:
            results = [m for m in results if tag in m.tags]
        if framework:
            results = [m for m in results if m.framework == framework]
        return results

    def get_model(self, model_id: str) -> Optional[AIModel]:
        for m in MODEL_CATALOG:
            if m.id == model_id:
                return m
        return None

    def install(self, model_id: str) -> bool:
        if model_id in self.installed:
            logger.info(f"Model {model_id} already installed")
            return True

        model = self.get_model(model_id)
        if not model:
            logger.error(f"Model {model_id} not found")
            return False

        logger.info(f"Installing model: {model.name} ({model.parameters})")

        model_path = Path(self.config.model_dir) / model_id
        model_path.mkdir(parents=True, exist_ok=True)

        if model.framework == "ollama":
            try:
                subprocess.run(["ollama", "pull", model.model_url.split("://")[1]],
                             check=True, capture_output=True)
            except FileNotFoundError:
                logger.warning("Ollama not installed, storing metadata only")

        elif model.framework == "huggingface":
            try:
                from huggingface_hub import snapshot_download
                snapshot_download(model.model_url.split("://")[1], local_dir=str(model_path))
            except ImportError:
                logger.warning("huggingface_hub not installed")
                (model_path / "metadata.json").write_text(json.dumps(asdict(model), indent=2))
        else:
            (model_path / "metadata.json").write_text(json.dumps(asdict(model), indent=2))

        self.installed[model_id] = InstalledModel(
            model_id=model_id,
            version=model.version,
            installed_at=datetime.now().isoformat(),
            path=str(model_path),
            size_gb=model.size_gb,
            backend=model.framework,
            enabled=True,
            config={"gpu_offload": self.config.gpu_offload_layers}
        )
        self._save_installed()

        logger.info(f"Model {model.name} installed successfully")
        return True

    def uninstall(self, model_id: str) -> bool:
        if model_id not in self.installed:
            logger.info(f"Model {model_id} not installed")
            return True

        if model_id in self.installed and self.installed[model_id].framework == "ollama":
            try:
                subprocess.run(["ollama", "rm", model_id], capture_output=True)
            except FileNotFoundError:
                pass

        model_path = Path(self.installed[model_id].path)
        if model_path.exists():
            shutil.rmtree(model_path)

        del self.installed[model_id]
        self._save_installed()
        logger.info(f"Model {model_id} uninstalled")
        return True

    def list_installed(self) -> List[InstalledModel]:
        return list(self.installed.values())

    def run(self, model_id: str, prompt: str, **kwargs) -> str:
        if model_id not in self.installed:
            return f"Model {model_id} not installed. Install with: orionos-ai-model install {model_id}"

        model_info = self.installed[model_id]

        if model_info.backend == "ollama":
            try:
                result = subprocess.run(
                    ["ollama", "run", model_id, prompt],
                    capture_output=True, text=True, timeout=300
                )
                return result.stdout
            except FileNotFoundError:
                return "Ollama not installed"
            except subprocess.TimeoutExpired:
                return "Request timed out"

        return f"Backend {model_info.backend} not yet supported for direct inference"

    def chat(self, model_id: str, messages: List[Dict[str, str]], **kwargs) -> str:
        if model_id not in self.installed:
            return f"Model {model_id} not installed"

        model_info = self.installed[model_id]

        if model_info.backend == "ollama":
            try:
                result = subprocess.run(
                    ["ollama", "run", model_id],
                    input="\n".join([m["content"] for m in messages]),
                    capture_output=True, text=True, timeout=300
                )
                return result.stdout
            except (FileNotFoundError, subprocess.TimeoutExpired) as e:
                return f"Error: {e}"

        return "Chat not supported for this backend"

    def list_catalog(self) -> List[AIModel]:
        return MODEL_CATALOG

    def list_categories(self) -> List[str]:
        categories = set()
        for m in MODEL_CATALOG:
            categories.update(m.tags)
        return sorted(categories)

    def get_recommended(self, task: str = "general", ram_gb: int = 16, gpu_gb: int = 0) -> List[AIModel]:
        task_tags = {
            "general": ["general", "chat", "fast"],
            "coding": ["coding", "programming"],
            "creative": ["creative", "image", "generation"],
            "speech": ["speech", "transcription", "audio"],
            "reasoning": ["reasoning", "advanced", "multilingual"],
        }
        tags = task_tags.get(task, [task])
        candidates = [m for m in MODEL_CATALOG if any(t in m.tags for t in tags)]

        if gpu_gb > 0:
            suitable = [m for m in candidates if m.min_ram_gb <= ram_gb and m.gpu_memory_gb <= gpu_gb]
        else:
            suitable = [m for m in candidates if not m.gpu_required and m.min_ram_gb <= ram_gb]

        return sorted(suitable, key=lambda m: m.downloads, reverse=True)


def load_config() -> MarketplaceConfig:
    config_file = CONFIG_DIR / "ai-marketplace.conf"
    if config_file.exists():
        try:
            with open(config_file) as f:
                return MarketplaceConfig(**json.load(f))
        except (json.JSONDecodeError, TypeError):
            pass
    return MarketplaceConfig()


def main():
    parser = argparse.ArgumentParser(description="OrionOS AI Model Marketplace")
    sub = parser.add_subparsers(dest="command")

    s_search = sub.add_parser("search", help="Search models")
    s_search.add_argument("query", nargs="?", default="")
    s_search.add_argument("--tag", default="")
    s_search.add_argument("--framework", default="")

    s_install = sub.add_parser("install", help="Install a model")
    s_install.add_argument("model_id")

    sub.add_parser("list", help="List installed models")
    sub.add_parser("catalog", help="Browse model catalog")

    s_run = sub.add_parser("run", help="Run inference")
    s_run.add_argument("model_id")
    s_run.add_argument("prompt")

    s_chat = sub.add_parser("chat", help="Interactive chat")
    s_chat.add_argument("model_id")

    s_rec = sub.add_parser("recommend", help="Get recommendations")
    s_rec.add_argument("--task", default="general")
    s_rec.add_argument("--ram", type=int, default=16)
    s_rec.add_argument("--gpu", type=int, default=0)

    s_uninstall = sub.add_parser("uninstall", help="Uninstall a model")
    s_uninstall.add_argument("model_id")

    args = parser.parse_args()
    config = load_config()
    marketplace = AIModelMarketplace(config)

    if args.command == "search":
        models = marketplace.search(args.query, args.tag, args.framework)
        if not models:
            print("No models found")
            return
        for m in models:
            inst = " [Installed]" if m.id in marketplace.installed else ""
            print(f"  {m.id}: {m.name} ({m.parameters}, {m.quantization}){inst}")
            print(f"    {m.description}")
            print(f"    Size: {m.size_gb}GB | RAM: {m.min_ram_gb}GB | GPU: {'Yes' if m.gpu_required else 'No'}")
            print(f"    Downloads: {m.downloads:,} | Rating: {m.rating}/5")
            print()

    elif args.command == "install":
        marketplace.install(args.model_id)

    elif args.command == "uninstall":
        marketplace.uninstall(args.model_id)

    elif args.command == "list":
        models = marketplace.list_installed()
        if not models:
            print("No models installed")
            return
        for m in models:
            print(f"  {m.model_id} v{m.version} [{m.backend}] ({m.size_gb}GB) installed: {m.installed_at}")

    elif args.command == "catalog":
        for cat in marketplace.list_categories():
            count = len([m for m in MODEL_CATALOG if cat in m.tags])
            print(f"  {cat} ({count} models)")

    elif args.command == "run":
        output = marketplace.run(args.model_id, args.prompt)
        print(output)

    elif args.command == "chat":
        print(f"Chatting with {args.model_id}. Type 'quit' to exit.")
        messages = []
        while True:
            try:
                user_input = input("You: ").strip()
                if user_input.lower() in ("quit", "exit", "q"):
                    break
                messages.append({"role": "user", "content": user_input})
                response = marketplace.chat(args.model_id, messages)
                print(f"AI: {response}")
                messages.append({"role": "assistant", "content": response})
            except (EOFError, KeyboardInterrupt):
                break

    elif args.command == "recommend":
        models = marketplace.get_recommended(args.task, args.ram, args.gpu)
        if not models:
            print("No suitable models found")
            return
        print(f"Recommended models for '{args.task}' ({args.ram}GB RAM, {args.gpu}GB VRAM):")
        for m in models[:5]:
            print(f"  {m.id}: {m.name} ({m.parameters}) - {m.size_gb}GB")

    else:
        parser.print_help()


if __name__ == "__main__":
    main()
