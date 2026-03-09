{ pkgs, config, nullclaw, ... }:

let
  hostname = config.networking.hostName;
  hasOpenSandbox = hostname == "workstation" || hostname == "nas";

  # Each server uses its local ollama; other hosts default to workstation.
  ollamaModel = {
    workstation = "gemma3:12b";
    nas = "qwen3.5-9b-q4km";
  }.${hostname} or "gemma3:12b";

  ollamaUrl = {
    workstation = "http://localhost:11434";
    nas = "http://localhost:11434";
  }.${hostname} or "http://100.95.201.10:11434";
in
{
  environment.systemPackages = [
    nullclaw.packages.${pkgs.system}.default
  ] ++ pkgs.lib.optionals hasOpenSandbox [
    (pkgs.python3.withPackages (ps: [
      pkgs.opensandbox-sdk
      pkgs.opensandbox-code-interpreter
    ]))
  ];

  environment.sessionVariables = {
    OLLAMA_MODEL = ollamaModel;
    OLLAMA_BASE_URL = ollamaUrl;
  };
}
