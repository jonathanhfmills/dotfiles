# NAS vLLM — AMD 9070 XT (16GB VRAM, ROCm)
# Qwen3.5-9B @ 4-bit: ~5GB weights, ~10GB KV cache headroom, 32K ctx x 2 parallel
# Docker: rocm/vllm-dev:latest with gfx1201 (RDNA 4) support
{ pkgs, ... }:

{
  virtualisation.oci-containers.containers.vllm = {
    image = "rocm/vllm-dev:latest";
    extraOptions = [
      "--device=/dev/kfd"
      "--device=/dev/dri"
      "--group-add=video"
      "--ipc=host"
      "--shm-size=8g"
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
    cmd = [
      "--model" "Qwen/Qwen3.5-9B"
      "--quantization" "bitsandbytes"
      "--load-format" "bitsandbytes"
      "--dtype" "float16"
      "--max-model-len" "32768"
      "--reasoning-parser" "qwen3"
      "--enable-auto-tool-choice"
      "--tool-call-parser" "qwen3_coder"
      "--enable-prefix-caching"
      "--gpu-memory-utilization" "0.95"
      "--api-key" "ollama"
      "--host" "0.0.0.0"
      "--port" "11434"
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
