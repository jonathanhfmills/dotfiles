# NAS 0.8B CPU Worker — i5-13600K E-cores
# Qwen3.5-0.8B @ 4-bit: ~0.5GB weights, 4K ctx
# Ultra-fast local tool calls (<50ms), zero network roundtrip
# Escalates to 9B GPU if task requires reasoning
# Uses vLLM CPU — same OpenAI-compatible API as GPU models
# Trajectories logged alongside 9B outputs for nightly GSPO scoring
{ pkgs, lib, ... }:

{
  virtualisation.oci-containers.containers.llm-worker = {
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
      "--api-key" "ollama"
      "--host" "127.0.0.1"
      "--port" "11436"
    ];
  };

  # Pin to E-cores — leaves P-cores free for GPU model overhead
  systemd.services.docker-llm-worker.serviceConfig = {
    CPUAffinity = "12 13 14 15 16 17 18 19";
    AllowedCPUs = "12-19";
    TimeoutStartSec = lib.mkForce 900;
  };

  # NOT auto-started — vLLM CPU doesn't support Qwen3.5 hybrid Mamba yet
  # (dispatch_cpu_unquantized_gemm fails on 3D Mamba weights)
  # Enable when vLLM adds Qwen3.5 CPU support
  systemd.services.docker-llm-worker.wantedBy = lib.mkForce [];
}
