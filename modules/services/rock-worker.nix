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
    set -e
    export PYTHONPATH="${rockPkgs}:''${PYTHONPATH:-}"
    export PATH="${rockPkgs}/bin:$PATH"
    if [ ! -f "${marker}" ]; then
      echo "Installing ROCK worker..."
      # rocklet extra requires gem-llm (internal Alibaba, not on PyPI) — install base only
      pip install --use-deprecated=legacy-resolver --target="${rockPkgs}" \
        "rl-rock" \
        "nacos-sdk-python==2.0.2" \
        pytz bashlex psutil
      rm -f "${rockPkgs}/uuid.py" "${rockPkgs}/UUID.py"
      rm -rf "${rockPkgs}"/uuid-*.dist-info
      touch "${marker}"
    fi
    # rocklet is the worker binary — 'rock worker start' subcommand does not exist
    exec rocklet
  '';
in
{
  systemd.tmpfiles.rules = [
    "d /var/lib/rock 0755 root root -"
    "d /var/lib/rock/packages 0755 root root -"
  ];

  systemd.services.rock-worker = {
    description = "ROCK Worker — RL environment executor (${hostname})";
    # rocklet requires gem-llm (internal Alibaba package, not on PyPI) — disabled.
    # Ray actors on the admin node handle sandbox execution directly.
    enable = false;
    after = [ "network-online.target" "docker.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.python312 pkgs.python312Packages.pip ];
    environment = {
      ROCK_ADMIN_URL = adminUrl;
      ROCK_WORKER_ENV_TYPE = "uv";
      LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib";
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
