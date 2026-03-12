# NVIDIA ollama — RTX 3080 (10GB VRAM)
# Qwen 3.5 9B for agent compute (coding, review, deploy)
# Used by: workstation (RTX 3080)
{ pkgs, nixpkgs-unstable, ... }:

let
  unstable = import nixpkgs-unstable { system = pkgs.system; config.allowUnfree = true; };
in
{
  services.ollama = {
    enable = true;
    package = unstable.ollama-cuda;
    host = "0.0.0.0";
    loadModels = [ "qwen3.5:9b" ];
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
