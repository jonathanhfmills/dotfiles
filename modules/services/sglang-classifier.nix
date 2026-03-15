# Workstation 0.8B CPU Worker — i7-8700K CPU
# Qwen3.5-0.8B @ 4-bit: ~0.5GB weights, 4K ctx
# Local tool calls (<50ms), escalates to 9B GPU for reasoning
# Leaves the RTX 3080 free for 9B inference
# Uses vLLM (not SGLang) — simpler CPU support, no sgl-kernel dependency
#
# Note: File named sglang-classifier.nix for import compatibility.
{ pkgs, lib, ... }:

{
  virtualisation.oci-containers.containers.sglang-classifier = {
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
      "Qwen/Qwen3.5-0.8B"
      "--max-model-len" "4096"
      "--trust-remote-code"
      "--enable-auto-tool-choice"
      "--tool-call-parser" "qwen3_coder"
      "--api-key" "ollama"
      "--host" "127.0.0.1"
      "--port" "11436"
    ];
  };

  # Allow time for first-run model download
  systemd.services.docker-sglang-classifier.serviceConfig.TimeoutStartSec = lib.mkForce 900;

  # No firewall port — localhost only (127.0.0.1)
}
