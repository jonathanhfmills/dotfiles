# Workstation ollama — AMD 9070 XT (16GB VRAM)
# Gemma 3 12B Q4_0 with 4-bit KV cache → 64k context
{ pkgs, ... }:

{
  services.ollama = {
    enable = true;
    package = pkgs.ollama-vulkan;
    host = "0.0.0.0";
    loadModels = [ "gemma3:12b" ];
    environmentVariables = {
      OLLAMA_FLASH_ATTENTION = "1";
      OLLAMA_KV_CACHE_TYPE = "q4_0";
      OLLAMA_MAX_LOADED_MODELS = "1";
      OLLAMA_KEEP_ALIVE = "22m";
      OLLAMA_NUM_PARALLEL = "2";
    };
  };

  networking.firewall.allowedTCPPorts = [ 11434 ];
}
