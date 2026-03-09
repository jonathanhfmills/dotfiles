{ pkgs, config, nullclaw, ... }:

let
  hostname = config.networking.hostName;
  isWorkstation = hostname == "workstation";
in
{
  environment.systemPackages = [
    nullclaw.packages.${pkgs.system}.default
  ] ++ pkgs.lib.optionals isWorkstation [
    (pkgs.python3.withPackages (ps: [
      pkgs.opensandbox-sdk
      pkgs.opensandbox-code-interpreter
    ]))
  ];

  environment.sessionVariables = {
    OLLAMA_MODEL = "qwen3.5-9b-q6";
    OLLAMA_BASE_URL = "http://100.95.201.10:11434";
  };
}
