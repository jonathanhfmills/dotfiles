# NAS ollama — AMD 9070 XT (16GB VRAM)
# qwen3.5 9B Q4_K_M: ~5.5GB weights + 4x 64k KV cache slots (~2GB each) = ~13.5GB
# Leaves ~2.5GB headroom for Vulkan runtime overhead
{ pkgs, nixpkgs-unstable, ... }:

let
  unstable = import nixpkgs-unstable { system = pkgs.system; };
in
{
  services.ollama = {
    enable = true;
    package = unstable.ollama-vulkan;
    host = "0.0.0.0";
    loadModels = [ "qwen3.5:9b" ];
    environmentVariables = {
      OLLAMA_FLASH_ATTENTION = "1";
      OLLAMA_KV_CACHE_TYPE = "q4_0";
      OLLAMA_MAX_LOADED_MODELS = "1";
      OLLAMA_KEEP_ALIVE = "22m";
      # 4 parallel slots — one per concurrent agent session
      # Each slot: 64k context with Q4 KV cache ≈ 2GB VRAM
      # Total: 5.5GB (weights) + 8GB (4x KV) + 1GB (runtime) ≈ 14.5GB / 16GB
      OLLAMA_NUM_PARALLEL = "4";
      OLLAMA_NUM_CTX = "65536";
    };
  };

  networking.firewall.allowedTCPPorts = [ 11434 ];
}
