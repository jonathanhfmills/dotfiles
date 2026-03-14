# NAS vLLM — AMD 9070 XT (16GB VRAM, ROCm)
# Qwen3.5-9B @ 4-bit: ~5GB weights, ~10GB KV cache headroom, 32K ctx
# Docker: rocm/vllm-dev navi image with ROCm 7.2 for RDNA 4 (gfx1201) support
# vLLM upgraded at startup (--no-deps) for Qwen3.5 architecture support
# Tool calling: --enable-auto-tool-choice --tool-call-parser qwen3_coder
#
# Note: File named sglang.nix for import compatibility — actually runs vLLM.
# SGLang's sgl-kernel doesn't support RDNA 4 (gfx1201), only MI300/MI350.
{ pkgs, lib, ... }:

{
  virtualisation.oci-containers.containers.sglang = {
    image = "rocm/vllm-dev:rocm7.2_navi_ubuntu24.04_py3.12_pytorch_2.9_vllm_0.14.0rc0";
    extraOptions = [
      "--device=/dev/kfd"
      "--device=/dev/dri"
      "--group-add=video"
      "--ipc=host"
      "--network=host"
    ];
    environment = {
      # Navi image supports gfx1201 natively — no HSA override needed
      VLLM_ROCM_USE_AITER = "0";
      HF_HOME = "/models";
    };
    volumes = [
      "/var/lib/vllm/models:/models"
    ];
    # The navi image ships vLLM 0.14.0 which predates Qwen3.5 support.
    # Upgrade vLLM Python code (--no-deps keeps ROCm PyTorch intact).
    # Save/restore ROCm-compiled extensions around the upgrade.
    entrypoint = "/bin/bash";
    cmd = [
      "-c"
      ''
        # Save ROCm-compiled extensions before upgrading vLLM Python code
        cp -a /opt/venv/lib/python3.12/site-packages/vllm/_C*.so /tmp/ 2>/dev/null || true
        cp -a /opt/venv/lib/python3.12/site-packages/vllm/_rocm_C*.so /tmp/ 2>/dev/null || true
        ls -la /tmp/_*C*.so 2>/dev/null && echo "Saved ROCm extensions" || echo "No extensions found to save"

        pip install --no-deps -U vllm \
          --extra-index-url https://wheels.vllm.ai/nightly && \
        pip install -U "transformers>=5.2" "bitsandbytes>=0.49.2" && \

        # Restore ROCm-compiled extensions (custom ops: silu_and_mul, etc.)
        cp -a /tmp/_C*.so /opt/venv/lib/python3.12/site-packages/vllm/ 2>/dev/null || true
        cp -a /tmp/_rocm_C*.so /opt/venv/lib/python3.12/site-packages/vllm/ 2>/dev/null || true
        ls -la /opt/venv/lib/python3.12/site-packages/vllm/_*C*.so 2>/dev/null && echo "Restored ROCm extensions" || echo "WARNING: No ROCm extensions restored"

        exec vllm serve Qwen/Qwen3.5-9B \
          --quantization bitsandbytes \
          --load-format bitsandbytes \
          --dtype float16 \
          --max-model-len 32768 \
          --enforce-eager \
          --compilation-config '{"cudagraph_mode": "none"}' \
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

  # Allow time for vLLM upgrade + first-run model download (~18GB)
  systemd.services.docker-sglang.serviceConfig.TimeoutStartSec = lib.mkForce 1800;

  networking.firewall.allowedTCPPorts = [ 11434 ];
}
