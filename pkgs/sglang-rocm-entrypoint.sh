#!/bin/bash
set -euo pipefail

MARKER="/models/.sglang-installed"

if [ ! -f "$MARKER" ]; then
  echo "=== First run: installing SGLang for ROCm ==="

  # Build sgl-kernel from source for this GPU architecture
  echo "Cloning sgl-kernel..."
  git clone --depth 1 https://github.com/sgl-project/sglang.git /tmp/sglang

  echo "Building sgl-kernel for ROCm (this takes ~10 minutes)..."
  cd /tmp/sglang/sgl-kernel
  python setup_rocm.py install 2>&1 | tail -30
  cd /

  # Install SGLang without deps (base image has PyTorch/ROCm)
  echo "Installing SGLang..."
  pip install --no-deps "sglang[all]>=0.4"

  # Install runtime dependencies that the base image lacks
  echo "Installing runtime dependencies..."
  pip install "transformers>=5.2" "bitsandbytes>=0.49.2" \
    orjson ipython fastapi uvicorn uvloop httptools \
    interegular outlines_core pydantic compressed-tensors \
    mistral_common pillow

  rm -rf /tmp/sglang
  touch "$MARKER"
  echo "=== SGLang installation complete ==="
fi

echo "Starting SGLang server..."
exec python -m sglang.launch_server \
  --model-path Qwen/Qwen3.5-9B \
  --quantization bitsandbytes \
  --dtype float16 \
  --context-length 32768 \
  --disable-cuda-graph \
  --mem-fraction-static 0.90 \
  --trust-remote-code \
  --tool-call-parser qwen3_coder \
  --api-key ollama \
  --host 0.0.0.0 \
  --port 11434
