{ pkgs, ... }:

let
  caddyfile = pkgs.writeText "stremio-caddyfile" ''
    stremio.hellfireae.com {
      import cloudflare-tls
      bind 100.87.216.16
      reverse_proxy 127.0.0.1:11470
    }
  '';

  stremio-server = pkgs.stdenv.mkDerivation {
    pname = "stremio-server";
    version = "4.20.16";

    src = pkgs.fetchurl {
      url = "https://dl.strem.io/server/v4.20.16/desktop/server.js";
      sha256 = "0a3fr2gqyz25vxj9mswjqdchgf3sd3kjjs33phyhwpvnb3q8gs48";
    };

    dontUnpack = true;

    installPhase = ''
      mkdir -p $out/share/stremio-server
      cp $src $out/share/stremio-server/server.js
    '';
  };
in
{
  systemd.services.stremio-server = {
    description = "Stremio Streaming Server";
    after = [ "network-online.target" "tailscaled.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    environment = {
      FFMPEG_BIN = "${pkgs.ffmpeg}/bin/ffmpeg";
      FFPROBE_BIN = "${pkgs.ffmpeg}/bin/ffprobe";
      APP_PATH = "/var/lib/stremio-server";
      NO_CORS = "1";
      CASTING_DISABLED = "1";
    };

    serviceConfig = {
      ExecStart = "${pkgs.nodejs_20}/bin/node ${stremio-server}/share/stremio-server/server.js";
      DynamicUser = true;
      StateDirectory = "stremio-server";

      # Hardening
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };

  networking.firewall.allowedTCPPorts = [ 11470 ];

  # Caddy vhost — picked up by `import /var/www/html/*/caddyfile` in caddy.nix
  systemd.tmpfiles.rules = [
    "d /var/www/html/stremio 0755 root root -"
    "L+ /var/www/html/stremio/caddyfile - - - - ${caddyfile}"
  ];
}
