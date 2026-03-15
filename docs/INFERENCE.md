# Inference Stack

## Model Map

| Host | Port | Model | Quantization | Engine | Size | Role |
|------|------|-------|-------------|--------|------|------|
| **Wanda GPU** | 11434 | Crow-9B | fp8 | SGLang (ROCm) | ~9GB | Brain — Hermes primary inference |
| **Cosmo GPU** | 11434 | Qwen3.5-9B-PARO | INT4 ParoQuant | vLLM (CUDA) | ~4.5GB | Engineer — code execution, tool calling |
| **Cosmo CPU** | 11436 | Qwen3.5-0.8B | INT4 AutoRound | vLLM CPU | ~0.4GB | Classifier — fast tool calls, routing |
| **Wanda CPU** | 11435 | Qwen3.5-35B-A3B MoE | INT4 | SGLang CPU | ~17.5GB | Scorer — overnight GSPO only |

All endpoints use OpenAI-compatible API with `--api-key ollama`.

## Models

### Crow-9B (Source of Truth)

[crownelius/Crow-9B-Opus-4.6-Distill-Heretic_Qwen3.5](https://huggingface.co/crownelius/Crow-9B-Opus-4.6-Distill-Heretic_Qwen3.5)

Claude Opus 4.6 knowledge distilled into Qwen3.5-9B with heretic uncensorship (based on `trohrbaugh/Qwen3.5-9B-heretic-v2`). bf16 safetensors.

- **Why Opus distill:** Frontier-grade reasoning in a local 9B model
- **Why heretic:** Medical accuracy over unnecessary safeguards — real-world business use
- **Architecture:** Qwen3.5-9B hybrid Mamba+attention — `qwen3_coder` tool calling preserved
- **Training target:** All GSPO training happens against this model's weights

### Qwen3.5-9B-PARO (Cosmo GPU)

[z-lab/Qwen3.5-9B-PARO](https://huggingface.co/z-lab/Qwen3.5-9B-PARO)

ParoQuant INT4 quantization of base Qwen3.5-9B. Used on Cosmo until the first training cycle completes, then replaced by locally re-quantized Crow-9B via `requantize-paro.sh`.

### Qwen3.5-0.8B (Cosmo CPU)

Base Qwen3.5-0.8B quantized with Intel AutoRound INT4. Runs on 8700K CPU for ultra-fast tool calls (<50ms). Re-quantized weekly after GSPO training via `quantize-08b-autoround.sh`.

### Qwen3.5-35B-A3B MoE (Scorer)

MoE architecture: 35B total params, 3B active per token. Used **only** for scoring — reward/punishment signal for GSPO training. NOT for inference. Started by training timer, stopped before morning.

**Requires:** NAS RAM upgrade to 32GB.

## Engines

### SGLang (Wanda — ROCm)

SGLang chosen for Wanda because:
- RadixAttention for multi-turn KV cache reuse
- Compressed FSM for 3x faster JSON/tool-call output
- Native `qwen3_coder` tool call parser
- `--disable-cuda-graph` replaces vLLM's `--enforce-eager`

**ROCm specifics:**
- Base image: `rocm/vllm-dev:rocm7.2_navi_ubuntu24.04` (RDNA 4 / gfx1201)
- sgl-kernel built from source with gfx1201 patch
- `SGLANG_USE_AITER=0` (aiter.ops.triton.gemm not available on RDNA 4)
- First run: ~15 min (compile + download), then cached in `/models/.sglang-packages/`

**Config:** `modules/services/sglang.nix` + `pkgs/sglang-rocm-entrypoint.sh`

### vLLM + ParoQuant (Cosmo GPU — CUDA)

vLLM chosen for Cosmo because:
- ParoQuant requires vLLM (CUDA kernels for INT4 dequant)
- Training pipeline (ms-swift, AutoRound) uses vLLM/transformers ecosystem
- RTX 3080 has full CUDA support

**Config:** `modules/services/vllm-nvidia.nix` + `pkgs/vllm-paro-entrypoint.sh`

ParoQuant installed at first boot via entrypoint script. Prefers local trained weights (`/models/crow-9b-paro/`), falls back to HuggingFace.

### vLLM CPU + AutoRound (Cosmo CPU)

Intel AutoRound INT4: accuracy-first quantization using sign-gradient descent. Native CPU support — no CUDA required.

**Config:** `modules/services/vllm-08b.nix`

Not auto-started — needs `quantize-08b-autoround.sh` to create the quantized model first.

## Quantization Pipeline

### ParoQuant (9B, weekly on Cosmo GPU)

```bash
# After LoRA merge on Wanda:
bash pkgs/swift-training/requantize-paro.sh
```

1. Optimize rotation parameters on merged Crow-9B (~15-30 min GPU)
2. Export INT4 safetensors checkpoint
3. Atomic swap — replace old PARO with new
4. Restart vLLM to load new weights

### AutoRound (0.8B, weekly on Cosmo CPU)

```bash
bash pkgs/swift-training/quantize-08b-autoround.sh
```

1. Merge 0.8B LoRA adapter into base weights (if exists)
2. AutoRound INT4 quantization (sign-gradient descent, 200 iterations)
3. Atomic swap
4. Restart vLLM CPU to load

### Testing Quantization

```bash
# Verify both methods work before relying on them:
pip install auto-round "paroquant[vllm]" vllm
bash pkgs/swift-training/test-quantization.sh
```

Tests: AutoRound quantize on CPU → verify load → ParoQuant quantize on GPU → verify load. Uses 0.8B for fast iteration (~5 min total).

## LoRA Hot-Swap

SGLang (Wanda) supports runtime LoRA loading via `--enable-lora`:

```bash
# Entrypoint auto-discovers adapters in /models/adapters/
# Each adapter: /models/adapters/<name>/adapter_config.json
# Request with: model="crow-9b:adapter-name"
```

vLLM (Cosmo) uses full weight replacement instead — merge LoRA → re-quantize → restart. Weekly cadence.

## Context Length

| Host | Model Size | VRAM | Available for KV | Est. Context |
|------|-----------|------|-----------------|-------------|
| Wanda | ~9GB (fp8) | 16GB | ~5-6GB | 64K-128K |
| Cosmo GPU | ~4.5GB (PARO) | 10GB | ~4-5GB | 32K-64K |
| Cosmo CPU | ~0.4GB (AR) | RAM | Plenty | 8K (limited by speed) |

Qwen3.5's hybrid Mamba architecture means only ~25% of layers use KV cache. Context scales ~4x better than pure transformers.
