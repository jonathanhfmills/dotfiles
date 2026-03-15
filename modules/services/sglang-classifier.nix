# Workstation vLLM Classifier — i7-8700K CPU
# Qwen3.5-0.8B @ 4-bit: ~0.5GB weights, 8K ctx
# Ultra-cheap classification and formatting tier — NullClaw Grunts hit this
# Leaves the RTX 3080 free for real 4B inference
# Uses vLLM (not SGLang) — simpler CPU support, no sgl-kernel dependency
#
# Note: File named sglang-classifier.nix for import compatibility.
{ pkgs, lib, ... }:

{
  virtualisation.oci-containers.containers.sglang-classifier = {
    image = "vllm/vllm-cpu:latest";
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
      "--model" "Qwen/Qwen3.5-0.8B"
      "--quantization" "bitsandbytes"
      "--max-model-len" "8192"
      "--trust-remote-code"
      "--device" "cpu"
      "--api-key" "ollama"
      "--host" "0.0.0.0"
      "--port" "11435"
    ];
  };

  # Allow time for first-run model download
  systemd.services.docker-sglang-classifier.serviceConfig.TimeoutStartSec = lib.mkForce 900;

  networking.firewall.allowedTCPPorts = [ 11435 ];
}
