#!/bin/bash
set -euo pipefail

# Persistent pip target on host-mounted volume (survives container restarts).
# The container uses --rm, so /opt/venv is ephemeral. This persists packages.
PIP_DIR="/models/.sglang-packages"
MARKER="/models/.sglang-installed-v23"

# Add persistent dir to PYTHONPATH.
# NOTE: PYTHONPATH entries go BEFORE site-packages in sys.path, so packages
# in PIP_DIR shadow the base image. We handle this by deleting conflicting
# packages from PIP_DIR after install (Step 5).
export PYTHONPATH="${PYTHONPATH:+${PYTHONPATH}:}${PIP_DIR}"

if [ ! -f "$MARKER" ]; then
  echo "=== First run: installing SGLang main branch for ROCm (RDNA 4 / gfx1201) ==="
  rm -rf "$PIP_DIR"
  mkdir -p "$PIP_DIR"

  # ── Step 1: Clone SGLang main branch ──
  # Main branch has AWQ Triton kernels for ROCm (awq_triton.py).
  # v0.5.9 only had Marlin-based AWQ/GPTQ which is NVIDIA-only.
  # aiter is disabled via SGLANG_USE_AITER=0 to avoid import crashes.
  echo "Cloning SGLang repo (main branch)..."
  git clone --depth 1 https://github.com/sgl-project/sglang.git /tmp/sglang

  # ── Step 2: Build sgl-kernel from source with gfx1201 target ──
  echo "Building sgl-kernel for gfx1201 (RDNA 4)..."
  cd /tmp/sglang/sgl-kernel

  if ! grep -q 'gfx1201' setup_rocm.py; then
    sed -i 's/if amdgpu_target not in \["gfx942", "gfx950"\]/if amdgpu_target not in ["gfx942", "gfx950", "gfx1201"]/' setup_rocm.py
  fi
  export AMDGPU_TARGET=gfx1201

  # Build and install to default location first, then extract to persistent dir
  if python setup_rocm.py install 2>&1 | tee /tmp/sgl-kernel-build.log | tail -20; then
    echo "=== sgl-kernel built for gfx1201 ==="
    # Extract the sgl_kernel package from the egg into the persistent dir
    EGG_DIR=$(ls -d /opt/venv/lib/python3.12/site-packages/sgl_kernel-*.egg 2>/dev/null | head -1)
    if [ -d "$EGG_DIR/sgl_kernel" ]; then
      cp -r "$EGG_DIR/sgl_kernel" "$PIP_DIR/"
      echo "Copied sgl-kernel to persistent dir"
    elif [ -d "/opt/venv/lib/python3.12/site-packages/sgl_kernel" ]; then
      cp -r /opt/venv/lib/python3.12/site-packages/sgl_kernel "$PIP_DIR/"
      echo "Copied sgl-kernel (flat install) to persistent dir"
    else
      echo "WARNING: Could not find sgl-kernel package to copy"
    fi
  else
    echo "=== sgl-kernel build FAILED ==="
  fi

  cd /

  # ── Step 3: Install SGLang from source to persistent dir ──
  echo "Installing SGLang from source..."
  pip install --no-deps --target="$PIP_DIR" /tmp/sglang/python 2>&1 | tail -10

  # ── Step 4: Install runtime deps to persistent dir ──
  # Pin torchao<0.16 for torch 2.9.x compatibility (base image has 2.9.1).
  # Don't install transformers — base image has 4.56+ which SGLang needs.
  echo "Installing runtime dependencies..."
  pip install --target="$PIP_DIR" \
    IPython aiohttp anthropic blobfile compressed-tensors decord2 einops \
    fastapi gguf hf_transfer huggingface_hub interegular msgspec \
    ninja openai orjson outlines packaging \
    partial_json_parser pillow prometheus-client psutil pybase64 \
    pydantic python-multipart pyzmq requests scipy sentencepiece \
    setproctitle tiktoken timm tqdm \
    uvicorn uvloop watchfiles xgrammar \
    2>&1 | tail -10

  # ── Step 5: Remove packages that shadow ROCm base image ──
  # PYTHONPATH goes before site-packages in sys.path, so anything in PIP_DIR
  # shadows the base image. Delete packages the base image provides correctly.
  echo "Removing packages that shadow base image..."
  rm -rf "$PIP_DIR"/torch "$PIP_DIR"/torch-*.dist-info \
    "$PIP_DIR"/torchvision "$PIP_DIR"/torchvision-*.dist-info \
    "$PIP_DIR"/torchaudio "$PIP_DIR"/torchaudio-*.dist-info \
    "$PIP_DIR"/triton "$PIP_DIR"/triton-*.dist-info \
    "$PIP_DIR"/nvidia_* "$PIP_DIR"/nvidia-*.dist-info \
    "$PIP_DIR"/cuda_* "$PIP_DIR"/cuda-*.dist-info \
    "$PIP_DIR"/flashinfer* \
    "$PIP_DIR"/transformers "$PIP_DIR"/transformers-*.dist-info \
    "$PIP_DIR"/numpy "$PIP_DIR"/numpy-*.dist-info \
    "$PIP_DIR"/numpy.libs \
    "$PIP_DIR"/torchao "$PIP_DIR"/torchao-*.dist-info \
    2>/dev/null || true

  rm -rf /tmp/sglang
  touch "$MARKER"
  echo "=== SGLang installation complete ==="
fi

# ── Create aiter.ops.triton.gemm shim (every startup) ──
# Container is --rm, so /opt/venv is ephemeral. Must recreate shim each time.
# SGLang main branch expects aiter.ops.triton.gemm.fused.* but ROCm 7.2's
# aiter has a flat layout (aiter.ops.triton.fused_gemm_*). This breaks:
#   - quark quantization (MXFP4)
#   - qwen_vl and other multimodal processors
# Create a shim package that re-exports from the flat layout.
AITER_TRITON="/opt/venv/lib/python3.12/site-packages/aiter/ops/triton"
if [ -d "$AITER_TRITON" ] && [ ! -d "$AITER_TRITON/gemm" ]; then
  echo "Creating aiter.ops.triton.gemm shim..."
  mkdir -p "$AITER_TRITON/gemm/fused"
  touch "$AITER_TRITON/gemm/__init__.py" "$AITER_TRITON/gemm/fused/__init__.py"
  cat > "$AITER_TRITON/gemm/fused/fused_gemm_afp4wfp4_split_cat.py" << 'SHIMEOF'
try:
    from aiter.ops.triton.fused_gemm_afp4wfp4_split_cat import *
except ImportError:
    def fused_gemm_afp4wfp4_split_cat(*a, **kw):
        raise NotImplementedError("MXFP4 not available on RDNA4")
SHIMEOF
  cat > "$AITER_TRITON/gemm/gemm_afp4wfp4.py" << 'SHIMEOF'
try:
    from aiter.ops.triton.gemm_afp4wfp4 import *
except ImportError:
    def gemm_afp4wfp4(*a, **kw):
        raise NotImplementedError("MXFP4 not available on RDNA4")
SHIMEOF
fi

echo "Starting SGLang server..."
# Qwen3.5-9B-FP8 — pre-quantized fp8 checkpoint (~10GB VRAM on 16GB 9070 XT)
LORA_ARGS=""
ADAPTER_DIR="/models/adapters"
if [ -d "$ADAPTER_DIR" ] && ls "$ADAPTER_DIR"/*/adapter_config.json &>/dev/null; then
  # Build --lora-paths from existing adapters: name=path pairs
  LORA_PATHS=""
  for adapter in "$ADAPTER_DIR"/*/adapter_config.json; do
    dir=$(dirname "$adapter")
    name=$(basename "$dir")
    LORA_PATHS="${LORA_PATHS:+${LORA_PATHS} }${name}=${dir}"
  done
  LORA_ARGS="--enable-lora --lora-paths ${LORA_PATHS}"
  echo "LoRA adapters found: ${LORA_PATHS}"
else
  echo "No LoRA adapters found in ${ADAPTER_DIR}, starting without LoRA"
fi

exec python -m sglang.launch_server \
  --model-path lovedheart/Qwen3.5-9B-FP8 \
  --attention-backend triton \
  --quantization fp8 \
  --context-length 131072 \
  --kv-cache-dtype fp8_e4m3fn \
  --disable-cuda-graph \
  --mem-fraction-static 0.90 \
  --trust-remote-code \
  --tool-call-parser qwen3_coder \
  --api-key ollama \
  --host 0.0.0.0 \
  --port 11434 \
  $LORA_ARGS
