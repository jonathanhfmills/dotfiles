# NAS SGLang — AMD 9070 XT (16GB VRAM, ROCm)
# Qwen3.5-9B @ 4-bit: ~5GB weights, ~10GB KV cache headroom, 32K ctx
# Docker: rocm/vllm-dev navi image with ROCm 7.2 for RDNA 4 (gfx1201) support
# SGLang installed at startup on top of ROCm PyTorch base
{ pkgs, ... }:

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
      HF_HOME = "/models";
    };
    volumes = [
      "/var/lib/vllm/models:/models"
    ];
    # Install SGLang on top of the ROCm navi base image.
    # The navi image has PyTorch 2.9 with ROCm support — SGLang uses it directly.
    # --disable-cuda-graph required: CUDA-compiled extensions won't load on ROCm.
    # --enforce-eager uses pure PyTorch ops via ROCm backend.
    entrypoint = "/bin/bash";
    cmd = [
      "-c"
      ''
        pip install --no-deps "sglang[all]>=0.4" && \
        pip install -U "transformers>=5.2" "bitsandbytes>=0.49.2" && \
        exec python -m sglang.launch_server \
          --model-path Qwen/Qwen3.5-9B \
          --quantization bitsandbytes \
          --dtype float16 \
          --context-length 32768 \
          --disable-cuda-graph \
          --enforce-eager \
          --mem-fraction-static 0.90 \
          --trust-remote-code \
          --enable-auto-tool-choice \
          --tool-call-parser qwen3_coder \
          --api-key ollama \
          --host 0.0.0.0 \
          --port 11434
      ''
    ];
  };

  # Ensure model cache directory exists
  systemd.tmpfiles.rules = [
    "d /var/lib/vllm 0755 root root -"
    "d /var/lib/vllm/models 0755 root root -"
  ];

  # Allow time for SGLang install + first-run model download (~18GB)
  systemd.services.docker-sglang.serviceConfig.TimeoutStartSec = 1800;

  networking.firewall.allowedTCPPorts = [ 11434 ];
}
