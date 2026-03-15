#!/bin/bash
set -euo pipefail

# AutoRound INT4 quantize the 0.8B model for Cosmo CPU deployment
# Intel AutoRound: accuracy-first, sign-gradient descent, native CPU support
# Output: ~0.4GB INT4 model, runs on vLLM CPU with --quantization auto_round
# Runs on Cosmo (works on CPU or GPU for quantization)

MODEL_DIR="/var/lib/vllm/models"
ADAPTER_DIR="${MODEL_DIR}/adapters/08b-latest"
BASE_08B="Qwen/Qwen3.5-0.8B"
MERGED_DIR="${MODEL_DIR}/merged-08b"
AR_OUTPUT="${MODEL_DIR}/crow-08b-autoround"
AR_STAGING="${MODEL_DIR}/crow-08b-autoround-staging"

# ── Step 1: Merge LoRA if adapter exists ──
if [ -d "${ADAPTER_DIR}" ] && [ -f "${ADAPTER_DIR}/adapter_config.json" ]; then
  echo "=== Merging 0.8B LoRA adapter ==="
  python3 -c "
from peft import PeftModel
from transformers import AutoModelForCausalLM, AutoTokenizer
import torch

base = AutoModelForCausalLM.from_pretrained('${BASE_08B}', torch_dtype=torch.bfloat16, trust_remote_code=True)
model = PeftModel.from_pretrained(base, '${ADAPTER_DIR}')
merged = model.merge_and_unload()
merged.save_pretrained('${MERGED_DIR}')

tokenizer = AutoTokenizer.from_pretrained('${BASE_08B}', trust_remote_code=True)
tokenizer.save_pretrained('${MERGED_DIR}')
"
  SOURCE="${MERGED_DIR}"
  echo "Using merged 0.8B model"
else
  SOURCE="${BASE_08B}"
  echo "No 0.8B adapter found — quantizing base model"
fi

# ── Step 2: AutoRound INT4 quantization ──
echo "=== AutoRound INT4 quantization ==="
rm -rf "${AR_STAGING}"

python3 -c "
from auto_round import AutoRound
from transformers import AutoModelForCausalLM, AutoTokenizer

model = AutoModelForCausalLM.from_pretrained('${SOURCE}', torch_dtype='auto', trust_remote_code=True)
tokenizer = AutoTokenizer.from_pretrained('${SOURCE}', trust_remote_code=True)

rounder = AutoRound(
    model,
    tokenizer,
    bits=4,
    group_size=128,
    iters=200,
    device='cpu',
)
rounder.quantize()
rounder.save_quantized('${AR_STAGING}', format='auto_round')
print('AutoRound quantization complete')
"

# ── Step 3: Atomic swap ──
if [ -d "${AR_OUTPUT}" ]; then
  mv "${AR_OUTPUT}" "${AR_OUTPUT}.old"
fi
mv "${AR_STAGING}" "${AR_OUTPUT}"
rm -rf "${AR_OUTPUT}.old" "${MERGED_DIR}"

echo "=== 0.8B AutoRound INT4 quantization complete ==="
echo "Model ready at ${AR_OUTPUT}"
