# NAS vLLM — AMD 9070 XT (16GB VRAM, ROCm)
# Qwen3.5-9B @ 4-bit: ~5GB weights, ~10GB KV cache headroom, 32K ctx x 2 parallel
# Docker: rocm/vllm-dev navi image with ROCm 7.2 for RDNA 4 (gfx1201) support
{ pkgs, ... }:

{
  virtualisation.oci-containers.containers.vllm = {
    image = "rocm/vllm-dev:rocm7.2_navi_ubuntu24.04_py3.12_pytorch_2.9_vllm_0.14.0rc0";
    extraOptions = [
      "--device=/dev/kfd"
      "--device=/dev/dri"
      "--group-add=video"
      "--ipc=host"
      "--network=host"
    ];
    environment = {
      HSA_OVERRIDE_GFX_VERSION = "11.5.0";
      VLLM_ROCM_USE_AITER = "0";
      HF_HOME = "/models";
    };
    volumes = [
      "/var/lib/vllm/models:/models"
    ];
    # rocm/vllm-dev navi image ships transformers 4.57.6 which predates qwen3_5
    # support (added in transformers 5.2.0). vLLM 0.14.0 imports ALLOWED_LAYER_TYPES
    # which was renamed to ALLOWED_MLP_LAYER_TYPES in transformers 5.x.
    # Fix: upgrade transformers to 5.2.0, write a sitecustomize.py to monkey-patch
    # the renamed symbol before vLLM imports it, then run vllm serve.
    entrypoint = "/bin/bash";
    cmd = [
      "-c"
      ''
        pip install -q transformers==5.2.0 && \
        SITE_DIR=$(python3 -c "import site; print(site.getsitepackages()[0])") && \
        cat > "$SITE_DIR/sitecustomize.py" << 'PATCH'
# Monkey-patch: vLLM 0.14 imports ALLOWED_LAYER_TYPES, renamed in transformers 5.x
from transformers import configuration_utils
if hasattr(configuration_utils, "ALLOWED_MLP_LAYER_TYPES") and not hasattr(configuration_utils, "ALLOWED_LAYER_TYPES"):
    configuration_utils.ALLOWED_LAYER_TYPES = configuration_utils.ALLOWED_MLP_LAYER_TYPES
PATCH
        exec vllm serve Qwen/Qwen3.5-9B \
          --quantization bitsandbytes \
          --load-format bitsandbytes \
          --dtype float16 \
          --max-model-len 32768 \
          --reasoning-parser qwen3 \
          --enable-auto-tool-choice \
          --tool-call-parser qwen3_coder \
          --enable-prefix-caching \
          --gpu-memory-utilization 0.95 \
          --api-key ollama \
          --host 0.0.0.0 \
          --port 11434
      ''
    ];
  };

  # Ensure model cache directory exists
  systemd.tmpfiles.rules = [
    "d /var/lib/vllm 0755 root root -"
    "d /var/lib/vllm/models 0755 root root -"
  ];

  # Allow time for first-run model download (~18GB)
  systemd.services.docker-vllm.serviceConfig.TimeoutStartSec = 900;

  networking.firewall.allowedTCPPorts = [ 11434 ];
}
