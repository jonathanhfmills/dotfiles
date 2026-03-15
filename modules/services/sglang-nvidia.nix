# Workstation SGLang — RTX 3080 (10GB VRAM, CUDA)
# Crow-9B: Opus 4.6 distillation into Qwen3.5-9B, fp8 quantized at load (~9GB VRAM)
# Same model as NAS — consistent quality, one LoRA to train/deploy
# Trajectories logged to /var/lib/vllm/models/trajectories/raw/ for nightly GSPO
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
      "--model-path" "crownelius/Crow-9B-Opus-4.6-Distill-Heretic_Qwen3.5"
      "--quantization" "fp8"
      "--context-length" "32768"
      "--mem-fraction-static" "0.85"
      "--trust-remote-code"
      "--tool-call-parser" "qwen3_coder"
      "--reasoning-parser" "qwen3"
      "--api-key" "ollama"
      "--host" "0.0.0.0"
      "--port" "11434"
    ];
  };

  # Ensure model cache and trajectory directories exist
  systemd.tmpfiles.rules = [
    "d /var/lib/vllm 0755 root root -"
    "d /var/lib/vllm/models 0755 root root -"
    "d /var/lib/vllm/models/trajectories 0755 root root -"
    "d /var/lib/vllm/models/trajectories/raw 0755 root root -"
  ];

  # Allow time for first-run model download
  systemd.services.docker-sglang.serviceConfig.TimeoutStartSec = lib.mkForce 900;

  networking.firewall.allowedTCPPorts = [ 11434 ];
}
