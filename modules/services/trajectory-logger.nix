# Trajectory Logging Proxy — logs OpenAI API requests/responses as JSONL
# Sits between clients (port 11433) and SGLang (port 11434).
# Clients hit 11433 → proxy logs + forwards to 11434 → response logged + returned.
# Non-chat endpoints pass through without logging.
# Produces raw trajectory files for nightly GSPO training.
{ pkgs, config, lib, ... }:

let
  hostname = config.networking.hostName;
  source = if hostname == "nas" then "wanda"
           else if hostname == "workstation" then "cosmo"
           else hostname;

  pythonEnv = pkgs.python312.withPackages (ps: with ps; [
    aiohttp
  ]);

  loggerScript = builtins.path {
    path = ../../pkgs/trajectory-logger/logger.py;
    name = "trajectory-logger.py";
  };
in
{
  systemd.services.trajectory-logger = {
    description = "Trajectory Logging Proxy (${source})";
    after = [ "docker-sglang.service" ];
    wants = [ "docker-sglang.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      RestartSec = 5;
      ExecStart = "${pythonEnv}/bin/python ${loggerScript} --upstream http://localhost:11434 --port 11433 --source ${source}";
    };
  };

  # Clients should hit the proxy port (11433) instead of SGLang directly (11434)
  networking.firewall.allowedTCPPorts = [ 11433 ];
}
