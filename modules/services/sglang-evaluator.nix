# NAS vLLM Evaluator — i5-13600K E-cores (MoE 35B-A3B)
# Qwen3.5-35B-A3B @ 4-bit: ~17.5GB weights, 16K ctx
# Reward/punishment scorer ONLY — too slow for inference (~2-5 tok/s)
# Sole job: score trajectories as good (reward) or bad (punishment) for RL training
# 32GB RAM budget: 17.5GB weights + 2GB ARC + 3GB vLLM + 2GB OS = 7.5GB headroom
# Uses vLLM (not SGLang) — simpler CPU support, no sgl-kernel dependency
# REQUIRES: NAS RAM upgrade to 32GB (currently 24GB — service will fail)
#
# Note: File named sglang-evaluator.nix for import compatibility.
{ pkgs, lib, ... }:

{
  virtualisation.oci-containers.containers.sglang-evaluator = {
    image = "public.ecr.aws/q9t5s3a7/vllm-cpu-release-repo:latest";
    extraOptions = [
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
      "Qwen/Qwen3.5-35B-A3B"
      "--max-model-len" "16384"
      "--trust-remote-code"
      "--enable-auto-tool-choice"
      "--tool-call-parser" "qwen3_coder"
      "--api-key" "ollama"
      "--host" "0.0.0.0"
      "--port" "11435"
    ];
  };

  # Pin to E-cores (12-19) to keep P-cores free for 9B GPU model overhead
  systemd.services.docker-sglang-evaluator.serviceConfig = {
    CPUAffinity = "12 13 14 15 16 17 18 19";
    AllowedCPUs = "12-19";
    TimeoutStartSec = lib.mkForce 1800;  # 35B model takes longer to load
  };

  # NOT auto-started — training timer starts/stops it overnight
  systemd.services.docker-sglang-evaluator.wantedBy = lib.mkForce [];

  networking.firewall.allowedTCPPorts = [ 11435 ];
}
