# Inference Endpoints

## Active Endpoints

| Endpoint | Model | Engine | Role |
|----------|-------|--------|------|
| `Wanda:11434` | Crow-9B (fp8) | SGLang ROCm | Primary inference — Hermes brain |
| `Cosmo:11434` | Qwen3.5-9B-PARO (INT4) | vLLM CUDA | NullClaw experts, tool calling |
| `Cosmo:11436` | Qwen3.5-0.8B (INT4) | vLLM CPU | Classifier, fast routing |
| `Wanda:11435` | Qwen3.5-35B-A3B MoE (INT4) | SGLang CPU | GSPO scorer — overnight only |

All endpoints: OpenAI-compatible API, `--api-key ollama`.

## Operational Commands

```bash
# Tail service logs
journalctl -fu sglang          # Wanda: Crow-9B inference
journalctl -fu vllm            # Cosmo: PARO-9B inference
journalctl -fu training-timer  # Nightly GSPO pipeline

# Nightly training (runs automatically at midnight on Wanda)
bash pkgs/swift-training/train-gspo.sh

# Weekly re-quantize (Cosmo, after LoRA merge)
bash pkgs/swift-training/requantize-paro.sh             # 9B ParoQuant
bash pkgs/swift-training/quantize-08b-autoround.sh      # 0.8B AutoRound
```
