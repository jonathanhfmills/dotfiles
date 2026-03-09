# NAS ollama — NVIDIA RTX 3080 (10GB VRAM)
# Qwen 3.5 9B Q4_K_M with 4-bit KV cache → 32k context
{ pkgs, ... }:

let
  modelName = "qwen3.5-9b-q4km";
  ggufUrl = "https://huggingface.co/bartowski/Qwen_Qwen3.5-9B-GGUF/resolve/main/Qwen_Qwen3.5-9B-Q4_K_M.gguf";
  ggufFile = "Qwen_Qwen3.5-9B-Q4_K_M.gguf";
  modelDir = "/var/lib/ollama/imports";
in
{
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
    host = "0.0.0.0";
    loadModels = [];
    environmentVariables = {
      OLLAMA_FLASH_ATTENTION = "1";
      OLLAMA_KV_CACHE_TYPE = "q4_0";
      OLLAMA_MAX_LOADED_MODELS = "1";
      OLLAMA_KEEP_ALIVE = "22m";
      OLLAMA_NUM_PARALLEL = "2";
    };
  };

  # Download Q4_K_M GGUF from HuggingFace and import into ollama on first boot
  systemd.services.ollama-import-qwen = {
    description = "Import Qwen3.5-9B Q4_K_M into ollama";
    after = [ "ollama.service" ];
    requires = [ "ollama.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.curl pkgs.ollama-cuda ];
    serviceConfig = {
      Type = "oneshot";
      User = "ollama";
      Group = "ollama";
      RemainAfterExit = true;
    };
    script = ''
      # Skip if model already exists
      if ollama list 2>/dev/null | grep -q "${modelName}"; then
        echo "${modelName} already imported, skipping"
        exit 0
      fi

      mkdir -p ${modelDir}

      # Download GGUF if not already present
      if [ ! -f "${modelDir}/${ggufFile}" ]; then
        echo "Downloading ${ggufFile}..."
        curl -L -o "${modelDir}/${ggufFile}" "${ggufUrl}"
      fi

      # Create Modelfile and import — 32k context fits in 10GB with Q4_K_M + 4-bit KV
      cat > ${modelDir}/Modelfile <<MEOF
      FROM ${modelDir}/${ggufFile}
      PARAMETER num_ctx 32768
      MEOF

      echo "Creating ollama model ${modelName}..."
      ollama create ${modelName} -f ${modelDir}/Modelfile

      # Clean up GGUF after successful import
      rm -f "${modelDir}/${ggufFile}" "${modelDir}/Modelfile"
      echo "${modelName} imported successfully"
    '';
  };

  networking.firewall.allowedTCPPorts = [ 11434 ];
}
