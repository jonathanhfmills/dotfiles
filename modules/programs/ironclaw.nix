{ pkgs, config, ... }:

let
  hostname = config.networking.hostName;
  isWorkstation = hostname == "workstation";

  ironclaw = pkgs.stdenv.mkDerivation rec {
    pname = "ironclaw";
    version = "0.9.0";

    src = pkgs.fetchurl {
      url = "https://github.com/nearai/ironclaw/releases/download/v${version}/ironclaw-x86_64-unknown-linux-gnu.tar.gz";
      sha256 = "455343e7ea978c663d86269ae85704755bf51f0d6c705cc24c57adcd205f6326";
    };

    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = [ pkgs.stdenv.cc.cc.lib pkgs.openssl ];

    sourceRoot = "ironclaw-x86_64-unknown-linux-gnu";

    installPhase = ''
      install -Dm755 ironclaw $out/bin/ironclaw
    '';
  };
in
{
  # PostgreSQL + pgvector — workstation only (ZFS-backed, rpool/postgres, recordsize=16K)
  services.postgresql = pkgs.lib.mkIf isWorkstation {
    enable = true;
    extensions = ps: [ ps.pgvector ];
    ensureDatabases = [ "ironclaw" "jon" ];
    ensureUsers = [
      {
        name = "jon";
        ensureDBOwnership = true;
      }
    ];
    # Accept connections from Tailscale network
    settings.listen_addresses = pkgs.lib.mkForce "localhost,100.95.201.10";
    authentication = ''
      # Tailscale CGNAT range — trust (already authenticated by Tailscale)
      host ironclaw jon 100.64.0.0/10 trust
    '';
  };

  # Allow PostgreSQL through firewall on Tailscale — workstation only
  networking.firewall.allowedTCPPorts = pkgs.lib.mkIf isWorkstation [ 5432 ];

  # Grant jon ownership of ironclaw DB after ensureUsers creates the role
  systemd.services.ironclaw-db-setup = pkgs.lib.mkIf isWorkstation {
    description = "Set ironclaw database ownership";
    after = [ "postgresql-setup.service" ];
    wants = [ "postgresql-setup.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "postgres";
      ExecStart = ''
        ${pkgs.postgresql}/bin/psql -c "ALTER DATABASE ironclaw OWNER TO jon;"
      '';
    };
  };

  # Sync Wanda identity files from dotfiles into ironclaw workspace DB
  # Runs on every nixos-rebuild switch — workstation only (has local DB)
  system.activationScripts.ironclaw-identity-sync = pkgs.lib.mkIf isWorkstation {
    deps = [ "users" ];
    text = ''
      if ${pkgs.systemd}/bin/systemctl is-active --quiet postgresql; then
        ${pkgs.sudo}/bin/sudo -u postgres ${pkgs.postgresql}/bin/psql -d ironclaw -c "CREATE EXTENSION IF NOT EXISTS vector;" 2>/dev/null || true
        for file in IDENTITY.md SOUL.md USER.md; do
          if [ -f /home/jon/dotfiles/wanda/$file ]; then
            ${pkgs.sudo}/bin/sudo -u jon \
              env DATABASE_URL="postgres://jon@/ironclaw?host=/run/postgresql" \
                  DATABASE_BACKEND="postgres" \
                  OLLAMA_MODEL="qwen3-14b-128k" \
              ${ironclaw}/bin/ironclaw memory write "$file" < /home/jon/dotfiles/wanda/$file
          fi
        done
      fi
    '';
  };

  environment.sessionVariables = {
    OLLAMA_MODEL = "qwen3-14b-128k";
    DATABASE_URL = if isWorkstation
      then "postgres://jon@/ironclaw?host=/run/postgresql"
      else "postgres://jon@100.95.201.10/ironclaw";
    DATABASE_BACKEND = "postgres";
    OLLAMA_BASE_URL = "http://100.95.201.10:11434";
  };

  environment.systemPackages = [ ironclaw ];
}
