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
  # Custom ROCK config: omits pip requirements (all deps already in rockPkgs),
  # sets working_dir to rockPkgs, and disables warmup image pull.
  # Default rock-local.yml has 'pip: ./requirements_sandbox_actor.txt' which blocks
  # startup indefinitely when the file is absent.
  rockConfig = pkgs.writeText "rock-wanda.yml" ''
    ray:
        runtime_env:
            working_dir: ${rockPkgs}
        namespace: rock-sandbox-local

    warmup:
        images: []
  '';
  # Apply SQLite PRAGMAs before ROCK creates its schema.
  # page_size must be set before the database file exists.
  # recordsize=16K on ZFS aligns with page_size=16384 — one ZFS record per page.
  pragmaScript = pkgs.writeShellScript "rock-sqlite-init" ''
    ${pkgs.python312}/bin/python3 -c "
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
    set -e
    export PYTHONPATH="${rockPkgs}:''${PYTHONPATH:-}"
    export PATH="${rockPkgs}/bin:$PATH"
    if [ ! -f "${marker}" ]; then
      echo "Installing ROCK admin..."
      # --use-deprecated=legacy-resolver: rl-rock has conflicting transitive deps
      # ray==2.43.0: latest ray with Python 3.12 wheels (3.13 wheels don't exist yet)
      # nacos-sdk-python==2.0.2: v3 installs to v2/nacos/ (non-flat); v2 has flat nacos module
      # pytz, bashlex: runtime imports by rock.admin.scheduler and rocklet
      pip install --use-deprecated=legacy-resolver --target="${rockPkgs}" \
        "rl-rock[admin]" \
        "ray[default]==2.43.0" \
        psutil uvicorn fastapi apscheduler aiosqlite sqlmodel websockets redis \
        "nacos-sdk-python==2.0.2" \
        pytz bashlex
      # Remove PyPI 'uuid' package — it shadows stdlib uuid with Python 2 syntax
      rm -f "${rockPkgs}/uuid.py" "${rockPkgs}/UUID.py"
      rm -rf "${rockPkgs}"/uuid-*.dist-info
      touch "${marker}"
    fi
    # 'rock admin start' uses subprocess.Popen and exits immediately (fire-and-forget).
    # exec the 'admin' uvicorn binary directly so systemd tracks the real process.
    exec admin --env local --role admin --port 8081
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
    path = [ pkgs.python312 pkgs.python312Packages.pip ];
    environment = {
      ROCK_STORAGE_BACKEND = "sqlite";
      ROCK_SQLITE_PATH = "/var/lib/rock/rock.db";
      # pip: rocklet is pulled inside each sandbox container at env creation time.
      # This avoids needing gem-llm on the host (it's an internal Alibaba package).
      ROCK_WORKER_ENV_TYPE = "pip";
      # Custom config: removes missing pip requirements file + disables warmup pull.
      ROCK_CONFIG = "${rockConfig}";
      # Ray bundles compiled .so extensions that link against libstdc++.so.6.
      # nix-ld provides the dynamic linker; LD_LIBRARY_PATH covers remaining deps.
      LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib";
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
