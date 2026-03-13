# NAS vLLM CPU — i5-13600K E-cores (lightweight tier)
# Qwen3.5-0.8B @ 4-bit: ~0.5GB weights, 16K ctx for simple tasks
# Low confidence tier — classification, formatting, routine tasks
# Co-located on NAS alongside the 9B GPU instance (port 11435)
{ pkgs, ... }:

{
  virtualisation.oci-containers.containers.vllm-cpu = {
    image = "vllm/vllm-openai:latest";
    extraOptions = [
      "--ipc=host"
      "--shm-size=2g"
      "--network=host"
    ];
    environment = {
      HF_HOME = "/models";
    };
    volumes = [
      "/var/lib/vllm/models:/models"
    ];
    cmd = [
      "--model" "Qwen/Qwen3.5-0.8B"
      "--quantization" "bitsandbytes"
      "--load-format" "bitsandbytes"
      "--max-model-len" "16384"
      "--reasoning-parser" "qwen3"
      "--enable-auto-tool-choice"
      "--tool-call-parser" "qwen3_coder"
      "--enable-prefix-caching"
      "--api-key" "ollama"
      "--host" "0.0.0.0"
      "--port" "11435"
      "--device" "cpu"
    ];
  };

  # CPU affinity: E-cores (12-19) to keep P-cores free for 9B GPU model overhead
  systemd.services.docker-vllm-cpu.serviceConfig = {
    CPUAffinity = "12 13 14 15 16 17 18 19";
    AllowedCPUs = "12-19";
    TimeoutStartSec = 900;
  };

  networking.firewall.allowedTCPPorts = [ 11435 ];
}
