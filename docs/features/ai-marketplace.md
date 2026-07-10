# OrionOS AI Model Marketplace

## Overview
Download, manage, and run AI models from Ollama, Hugging Face, and OrionOS Hub.

## Supported Frameworks
- Ollama
- llama.cpp
- ONNX Runtime
- Hugging Face Transformers

## Usage

### Search Models
```bash
orionos-ai-model search "coding"
orionos-ai-model search --tag reasoning
```

### Install Model
```bash
orionos-ai-model install llama-3.1-8b
orionos-ai-model install deepseek-coder-33b
```

### Run Inference
```bash
orionos-ai-model run llama-3.1-8b "Explain quantum computing"
```

### Interactive Chat
```bash
orionos-ai-model chat llama-3.1-8b
```

### Get Recommendations
```bash
orionos-ai-model recommend --task coding --ram 16 --gpu 8
```

### Browse Catalog
```bash
orionos-ai-model catalog
orionos-ai-model list
```
