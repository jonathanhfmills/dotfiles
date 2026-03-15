# Workstation 0.8B classifier — 8700K CPU
# AutoRound INT4: ~0.4GB — Intel's accuracy-first quantization, native CPU support
# Preserves reasoning-critical weights via sign-gradient descent optimization
# Trained via GSPO nightly, re-quantized weekly with AutoRound
# Frees full 10GB VRAM for 9B PARO on GPU
{ pkgs, lib, ... }:

let
  localModel = "/models/crow-08b-autoround";
  fallbackModel = "Qwen/Qwen3.5-0.8B";
in
{
  virtualisation.oci-containers.containers.vllm-08b = {
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
      "--model" localModel
      "--quantization" "auto_round"
      "--max-model-len" "8192"
      "--trust-remote-code"
      "--enable-auto-tool-choice"
      "--tool-call-parser" "qwen3_coder"
      "--api-key" "ollama"
      "--host" "0.0.0.0"
      "--port" "11436"
    ];
  };

  systemd.services.docker-vllm-08b.serviceConfig.TimeoutStartSec = lib.mkForce 300;

  # Don't auto-start until first quantization is done
  # Run quantize-08b-autoround.sh first, then: systemctl start docker-vllm-08b
  systemd.services.docker-vllm-08b.wantedBy = lib.mkForce [];

  networking.firewall.allowedTCPPorts = [ 11436 ];
}
