# Workstation vLLM — RTX 3080 (10GB VRAM, CUDA)
# Crow-9B locally quantized via ParoQuant INT4 (~4.5GB weights)
# Source of truth: Crow-9B on Wanda → GSPO trains LoRA → merge weekly →
# Syncthing delivers merged weights → Cosmo re-quantizes with ParoQuant → reload
# Same Qwen3.5-9B architecture as Wanda — consistent tool calling
{ pkgs, lib, ... }:

{
  # nvidia-container-toolkit required for --gpus all
  hardware.nvidia-container-toolkit.enable = true;

  virtualisation.oci-containers.containers.vllm = {
    image = "vllm/vllm-openai:latest";
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
      "${builtins.path { path = ../../pkgs/vllm-paro-entrypoint.sh; name = "vllm-paro-entrypoint.sh"; }}:/entrypoint.sh:ro"
    ];
    entrypoint = "/bin/bash";
    cmd = [ "/entrypoint.sh"
      "--max-model-len" "32768"
      "--enable-auto-tool-choice"
      "--tool-call-parser" "qwen3_coder"
      "--reasoning-parser" "qwen3"
      "--enable-prefix-caching"
      "--gpu-memory-utilization" "0.90"
      "--api-key" "ollama"
    ];
  };

  # Ensure model cache and trajectory directories exist
  systemd.tmpfiles.rules = [
    "d /var/lib/vllm 0755 root root -"
    "d /var/lib/vllm/models 0755 root root -"
    "d /var/lib/vllm/models/trajectories 0755 root root -"
    "d /var/lib/vllm/models/trajectories/raw 0755 root root -"
    "d /var/lib/vllm/models/adapters 0777 root root -"
    "d /var/lib/vllm/models/merged-crow-9b 0755 root root -"
    "d /var/lib/vllm/models/crow-9b-paro 0755 root root -"
  ];

  # Allow time for first-run model download + paroquant install
  systemd.services.docker-vllm.serviceConfig.TimeoutStartSec = lib.mkForce 900;

  networking.firewall.allowedTCPPorts = [ 11434 ];
}
