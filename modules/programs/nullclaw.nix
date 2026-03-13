{ pkgs, config, nullclaw, ... }:

let
  hostname = config.networking.hostName;
  hasOpenSandbox = hostname == "workstation" || hostname == "nas";

  # Each server uses its local ollama; other hosts default to NAS (Wanda).
  ollamaModel = "qwen3.5:9b";

  ollamaUrl = {
    workstation = "http://localhost:11434";
    nas = "http://localhost:11434";
  }.${hostname} or "http://wanda:11434";
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
    ORCHESTRATOR_NAME = {
      nas = "wanda";
      workstation = "cosmo";
    }.${hostname} or "";
  };
}
