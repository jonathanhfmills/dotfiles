# Workstation vLLM — RTX 3080 (10GB VRAM, CUDA)
# Qwen3.5-4B @ 4-bit: ~2.5GB weights, plenty of KV cache room, 64K ctx x 2 parallel
# Medium confidence tier — execution, logic, code tasks
{ pkgs, ... }:

{
  # nvidia-container-toolkit required for --gpus all
  hardware.nvidia-container-toolkit.enable = true;

  virtualisation.oci-containers.containers.vllm = {
    image = "vllm/vllm-openai:latest";
    extraOptions = [
      "--gpus=all"
      "--ipc=host"
      "--shm-size=4g"
      "--network=host"
    ];
    environment = {
      HF_HOME = "/models";
    };
    volumes = [
      "/var/lib/vllm/models:/models"
    ];
    cmd = [
      "--model" "Qwen/Qwen3.5-4B"
      "--quantization" "bitsandbytes"
      "--load-format" "bitsandbytes"
      "--max-model-len" "65536"
      "--reasoning-parser" "qwen3"
      "--enable-auto-tool-choice"
      "--tool-call-parser" "qwen3_coder"
      "--enable-prefix-caching"
      "--gpu-memory-utilization" "0.90"
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
  systemd.services.docker-vllm.serviceConfig.TimeoutStartSec = 900;

  networking.firewall.allowedTCPPorts = [ 11434 ];
}
