# NAS ollama — AMD 9070 XT (16GB VRAM)
# qwen3.5 for orchestrator tool-use, gemma3:12b for research/content
{ pkgs, nixpkgs-unstable, ... }:

let
  unstable = import nixpkgs-unstable { system = pkgs.system; };
in
{
  services.ollama = {
    enable = true;
    package = unstable.ollama-vulkan;
    host = "0.0.0.0";
    loadModels = [ "qwen3.5" "gemma3:12b" ];
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
