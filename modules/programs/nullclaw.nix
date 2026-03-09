{ pkgs, config, nullclaw, ... }:

let
  hostname = config.networking.hostName;
  hasOpenSandbox = hostname == "workstation";

  # Each server uses its local ollama; other hosts default to workstation.
  ollamaModel = {
    workstation = "qwen3.5-9b-q4km";
    nas = "gemma3:12b";
  }.${hostname} or "qwen3.5-9b-q4km";

  ollamaUrl = {
    workstation = "http://localhost:11434";
    nas = "http://localhost:11434";
  }.${hostname} or "http://workstation:11434";
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
