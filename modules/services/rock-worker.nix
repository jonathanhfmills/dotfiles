# ROCK Worker — cosmo + wanda, executes RL sandbox environments
# Spawns Docker containers per GEM step (reset/step interface for ROLL).
# Connects to ROCK Admin on wanda:8081 via Tailscale.
{ pkgs, config, lib, ... }:
let
  hostname = config.networking.hostName;
  adminUrl = if hostname == "nas"
    then "http://localhost:8081"
    else "http://nas:8081";
  rockPkgs = "/var/lib/rock/packages";
  marker = "/var/lib/rock/.worker-installed";
  startScript = pkgs.writeShellScript "rock-worker-start" ''
    export PYTHONPATH="${rockPkgs}:''${PYTHONPATH:-}"
    export PATH="${rockPkgs}/bin:$PATH"
    if [ ! -f "${marker}" ]; then
      echo "Installing ROCK worker..."
      ${pkgs.python3}/bin/pip install --target="${rockPkgs}" "rl-rock[worker,rocklet]"
      touch "${marker}"
    fi
    exec rock worker start
  '';
in
{
  systemd.tmpfiles.rules = [
    "d /var/lib/rock 0755 root root -"
    "d /var/lib/rock/packages 0755 root root -"
  ];

  systemd.services.rock-worker = {
    description = "ROCK Worker — RL environment executor (${hostname})";
    after = [ "network-online.target" "docker.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.python3 ];
    environment = {
      ROCK_ADMIN_URL = adminUrl;
      ROCK_WORKER_ENV_TYPE = "docker";
    };
    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      RestartSec = 15;
      ExecStart = startScript;
      SupplementaryGroups = [ "docker" ];
      TimeoutStartSec = 600;
    };
  };
}
