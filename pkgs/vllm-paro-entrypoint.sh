#!/bin/bash
set -euo pipefail

# Cosmo vLLM entrypoint — serves Crow-9B (PARO INT4) + 0.8B (AWQ INT4) on RTX 3080
# 9B PARO: ~4.5GB + 0.8B AWQ: ~0.4GB = ~5GB total, leaves ~5GB for KV cache
# Prefers locally trained+quantized weights, falls back to HuggingFace

PIP_DIR="/models/.paro-packages"
MARKER="/models/.paro-installed-v1"

# Model paths — local trained > HuggingFace
LOCAL_PARO="/models/crow-9b-paro"
HF_PARO="z-lab/Qwen3.5-9B-PARO"
LOCAL_AWQ="/models/crow-08b-awq"
HF_08B="Qwen/Qwen3.5-0.8B"

# ── Install ParoQuant + AutoAWQ on first run ──
if [ ! -f "$MARKER" ]; then
  echo "=== First run: installing ParoQuant + AutoAWQ ==="
  pip install --target="$PIP_DIR" "paroquant[vllm]" autoawq 2>&1 | tail -10
  touch "$MARKER"
  echo "=== Installation complete ==="
fi

export PYTHONPATH="${PIP_DIR}:${PYTHONPATH:-}"

# ── Select 9B model ──
if [ -f "${LOCAL_PARO}/config.json" ]; then
  MODEL_PATH="$LOCAL_PARO"
  echo "9B: Loading locally quantized Crow-9B PARO"
else
  MODEL_PATH="$HF_PARO"
  echo "9B: Loading ${HF_PARO} from HuggingFace (run requantize-paro.sh after training)"
fi

echo "Starting vLLM via ParoQuant (model: ${MODEL_PATH})..."
exec python -m paroquant.cli.serve \
  --model "$MODEL_PATH" \
  --port 11434 \
  --host 0.0.0.0 \
  "$@"
