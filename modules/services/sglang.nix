# NAS SGLang — AMD 9070 XT (16GB VRAM, ROCm)
# Crow-9B (Opus 4.6 distill into Qwen3.5-9B) @ fp8: ~9GB weights, 64K-128K ctx
# Source of truth model — GSPO trains LoRA nightly, hot-swaps via --enable-lora
# Weekly: merge LoRA → Syncthing to Cosmo → ParoQuant re-quantize → deploy
# Docker: rocm/vllm-dev navi image with ROCm 7.2 for RDNA 4 (gfx1201) support
# SGLang installed at startup on top of ROCm PyTorch base
#
# sgl-kernel doesn't officially support RDNA 4 (gfx1201). The entrypoint:
#   1. Patches setup_rocm.py to accept gfx1201 and builds from source
#   2. If that fails, patches SGLang to fall back to vLLM's custom ops
# First run takes ~15 min (compile + download), subsequent runs skip install.
{ pkgs, lib, ... }:

{
  virtualisation.oci-containers.containers.sglang = {
    image = "rocm/vllm-dev:rocm7.2_navi_ubuntu24.04_py3.12_pytorch_2.9_vllm_0.14.0rc0";
    extraOptions = [
      "--device=/dev/kfd"
      "--device=/dev/dri"
      "--group-add=video"
      "--ipc=host"
      "--network=host"
    ];
    environment = {
      # Navi image supports gfx1201 natively — no HSA override needed
      VLLM_ROCM_USE_AITER = "0";
      # Disable aiter in SGLang — avoids aiter.ops.triton.gemm import crash
      # (ROCm 7.2 base image aiter doesn't have this module)
      SGLANG_USE_AITER = "0";
      # CuDNN check false-positive on ROCm (Conv3d bug doesn't apply)
      SGLANG_DISABLE_CUDNN_CHECK = "1";
      HF_HOME = "/models";
    };
    volumes = [
      "/var/lib/vllm/models:/models"
      "${builtins.path { path = ../../pkgs/sglang-rocm-entrypoint.sh; name = "sglang-entrypoint.sh"; }}:/entrypoint.sh:ro"
    ];
    entrypoint = "/bin/bash";
    cmd = [ "/entrypoint.sh" ];
  };

  # Ensure model cache and trajectory directories exist
  systemd.tmpfiles.rules = [
    "d /var/lib/vllm 0755 root root -"
    "d /var/lib/vllm/models 0755 root root -"
    "d /var/lib/vllm/models/trajectories 0777 root root -"
    "d /var/lib/vllm/models/trajectories/raw 0777 root root -"
    "d /var/lib/vllm/models/trajectories/scored 0777 root root -"
    "d /var/lib/vllm/models/adapters 0777 root root -"
  ];

  # Allow time for SGLang install + first-run model download (~18GB)
  systemd.services.docker-sglang.serviceConfig.TimeoutStartSec = lib.mkForce 1800;

  networking.firewall.allowedTCPPorts = [ 11434 ];
}
