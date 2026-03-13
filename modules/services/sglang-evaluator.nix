# NAS SGLang Evaluator — i5-13600K E-cores (MoE 35B-A3B)
# Qwen3.5-35B-A3B @ 4-bit: ~17.5GB weights, 16K ctx
# Reward/punishment scorer ONLY — too slow for inference (~2-5 tok/s)
# Sole job: score trajectories as good (reward) or bad (punishment) for RL training
# 32GB RAM budget: 17.5GB weights + 2GB ARC + 3GB SGLang + 2GB OS = 7.5GB headroom
{ pkgs, ... }:

{
  virtualisation.oci-containers.containers.sglang-evaluator = {
    image = "lmsysorg/sglang:latest";
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
      "--model-path" "Qwen/Qwen3.5-35B-A3B"
      "--quantization" "bitsandbytes"
      "--context-length" "16384"
      "--trust-remote-code"
      "--device" "cpu"
      "--api-key" "ollama"
      "--host" "0.0.0.0"
      "--port" "11435"
    ];
  };

  # Pin to E-cores (12-19) to keep P-cores free for 9B GPU model overhead
  systemd.services.docker-sglang-evaluator.serviceConfig = {
    CPUAffinity = "12 13 14 15 16 17 18 19";
    AllowedCPUs = "12-19";
    TimeoutStartSec = 1800;  # 35B model takes longer to load
  };

  networking.firewall.allowedTCPPorts = [ 11435 ];
}
