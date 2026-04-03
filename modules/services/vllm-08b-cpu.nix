# Fleet 0.8B CPU — all NixOS hosts (desktop, laptop, portable, nas)
# Qwen3.5-0.8B @ 4-bit bitsandbytes: ~0.4GB weights, 8K ctx
# Always-on local endpoint for lightweight tasks, tool calls, routing
# No GPU required — runs on any host CPU
{ pkgs, lib, ... }:

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
      "--model" "Qwen/Qwen3.5-0.8B"
      "--quantization" "bitsandbytes"
      "--load-format" "bitsandbytes"
      "--max-model-len" "8192"
      "--trust-remote-code"
      "--enable-auto-tool-choice"
      "--tool-call-parser" "qwen3_coder"
      "--api-key" "ollama"
      "--host" "0.0.0.0"
      "--port" "11436"
    ];
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/vllm 0755 root root -"
    "d /var/lib/vllm/models 0755 root root -"
  ];

  systemd.services.docker-vllm-08b.serviceConfig.TimeoutStartSec = lib.mkForce 600;

  networking.firewall.allowedTCPPorts = [ 11436 ];
}
