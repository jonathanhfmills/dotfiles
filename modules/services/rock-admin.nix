# ROCK Admin — wanda (NAS), GEM-protocol RL environment control plane
# Qwen3.5 was trained with ROCK — operating the same stack puts inference
# in-distribution, unlocking the model's pre-trained self-improvement patterns.
# Ray runs in local mode (no cluster needed), SQLite for state.
# Port 8081 — OpenSandbox occupies 8080.
{ pkgs, lib, ... }:
let
  rockDir = "/var/lib/rock";
  rockPkgs = "${rockDir}/packages";
  marker = "${rockDir}/.installed";
  # Apply SQLite PRAGMAs before ROCK creates its schema.
  # page_size must be set before the database file exists.
  # recordsize=16K on ZFS aligns with page_size=16384 — one ZFS record per page.
  pragmaScript = pkgs.writeShellScript "rock-sqlite-init" ''
    ${pkgs.python3}/bin/python3 -c "
import sqlite3, os
db = '/var/lib/rock/rock.db'
os.makedirs('/var/lib/rock', exist_ok=True)
con = sqlite3.connect(db)
con.execute('PRAGMA page_size = 16384')
con.execute('PRAGMA journal_mode = WAL')
con.execute('PRAGMA synchronous = NORMAL')
con.execute('PRAGMA cache_size = -32768')
con.execute('PRAGMA temp_store = MEMORY')
con.execute('PRAGMA wal_autocheckpoint = 1000')
con.commit()
con.close()
"
  '';
  startScript = pkgs.writeShellScript "rock-admin-start" ''
    export PYTHONPATH="${rockPkgs}:''${PYTHONPATH:-}"
    export PATH="${rockPkgs}/bin:$PATH"
    if [ ! -f "${marker}" ]; then
      echo "Installing ROCK admin..."
      ${pkgs.python3}/bin/pip install --target="${rockPkgs}" "rl-rock[admin,rocklet]"
      touch "${marker}"
    fi
    exec rock admin start --host 0.0.0.0 --port 8081
  '';
in
{
  systemd.tmpfiles.rules = [
    "d /var/lib/rock 0755 root root -"
    "d /var/lib/rock/packages 0755 root root -"
  ];

  systemd.services.rock-admin = {
    description = "ROCK Admin — RL environment orchestrator (GEM protocol)";
    after = [ "network-online.target" "docker.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.python3 ];
    environment = {
      ROCK_STORAGE_BACKEND = "sqlite";
      ROCK_SQLITE_PATH = "/var/lib/rock/rock.db";
    };
    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      RestartSec = 15;
      ExecStartPre = pragmaScript;
      ExecStart = startScript;
      SupplementaryGroups = [ "docker" ];
      TimeoutStartSec = 600;  # First run pip install takes a while
    };
  };

  networking.firewall.allowedTCPPorts = [ 8081 ];
}
