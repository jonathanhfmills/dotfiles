#!/bin/bash
set -euo pipefail

# Re-quantize Crow-9B with merged LoRA using ParoQuant for Cosmo deployment
# Runs on Cosmo (RTX 3080) — needs CUDA for ParoQuant optimization
# Triggered weekly after LoRA merge, or manually after significant training

MODEL_DIR="/var/lib/vllm/models"
MERGED_DIR="${MODEL_DIR}/merged-crow-9b"
PARO_OUTPUT="${MODEL_DIR}/crow-9b-paro"
PARO_STAGING="${MODEL_DIR}/crow-9b-paro-staging"
OPTIM_DIR="${MODEL_DIR}/paro-optim"

# ── Step 1: Check for merged model ──
if [ ! -f "${MERGED_DIR}/config.json" ]; then
  echo "No merged model found at ${MERGED_DIR}. Run merge-lora first."
  exit 1
fi

echo "=== ParoQuant re-quantization starting ==="
echo "Source: ${MERGED_DIR}"
echo "Output: ${PARO_OUTPUT}"

# ── Step 2: Optimize rotation parameters (GPU, ~15-30 min) ──
echo "=== Step 1/3: Optimizing rotation parameters ==="
rm -rf "${OPTIM_DIR}"
mkdir -p "${OPTIM_DIR}"

# ParoQuant optimize script — uses calibration data to find optimal rotations
python -c "
import subprocess, sys
# Run the 4bit optimization script with our merged model
result = subprocess.run([
    sys.executable, '-m', 'paroquant.optimize',
    '--model', '${MERGED_DIR}',
    '--output-dir', '${OPTIM_DIR}',
    '--bits', '4',
], capture_output=False)
if result.returncode != 0:
    # Fallback: use the experiments script directly
    subprocess.run([
        'bash', 'experiments/optimize/4bit.sh', '${MERGED_DIR}'
    ], check=True)
"

# ── Step 3: Export to HuggingFace checkpoint (INT4 safetensors) ──
echo "=== Step 2/3: Exporting INT4 checkpoint ==="
rm -rf "${PARO_STAGING}"
python -m paroquant.cli.convert \
  --model "${MERGED_DIR}" \
  --result-dir "${OPTIM_DIR}" \
  --output-path "${PARO_STAGING}" \
  --mode real

# ── Step 4: Atomic swap — replace old PARO with new ──
echo "=== Step 3/3: Deploying new quantization ==="
if [ -d "${PARO_OUTPUT}" ]; then
  mv "${PARO_OUTPUT}" "${PARO_OUTPUT}.old"
fi
mv "${PARO_STAGING}" "${PARO_OUTPUT}"
rm -rf "${PARO_OUTPUT}.old" "${OPTIM_DIR}"

echo "=== ParoQuant re-quantization complete ==="
echo "Restart vLLM to load new weights: systemctl restart docker-vllm"
