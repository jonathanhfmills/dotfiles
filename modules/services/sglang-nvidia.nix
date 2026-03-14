# Workstation SGLang — RTX 3080 (10GB VRAM, CUDA)
# Qwen3.5-4B @ 4-bit: ~2.5GB weights, plenty of KV cache room, 64K ctx
# Full CUDA support: graphs, fused kernels, RadixAttention — workhorse tier
# SGLang chosen over vLLM here because sgl-kernel builds natively on CUDA
{ pkgs, lib, ... }:

{
  # nvidia-container-toolkit required for --gpus all
  hardware.nvidia-container-toolkit.enable = true;

  virtualisation.oci-containers.containers.sglang = {
    image = "lmsysorg/sglang:latest";
    extraOptions = [
      "--gpus=all"
      "--ipc=host"
      "--network=host"
    ];
    environment = {
      HF_HOME = "/models";
    };
    volumes = [
      "/var/lib/vllm/models:/models"
    ];
    cmd = [
      "--model-path" "Qwen/Qwen3.5-4B"
      "--quantization" "bitsandbytes"
      "--context-length" "65536"
      "--mem-fraction-static" "0.85"
      "--trust-remote-code"
      "--tool-call-parser" "qwen3_coder"
      "--reasoning-parser" "qwen3"
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

  # Allow time for first-run model download
  systemd.services.docker-sglang.serviceConfig.TimeoutStartSec = lib.mkForce 900;

  networking.firewall.allowedTCPPorts = [ 11434 ];
}
