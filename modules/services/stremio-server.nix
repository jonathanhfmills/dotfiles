{ pkgs, ... }:

let
  caddyfile = pkgs.writeText "stremio-caddyfile" ''
    stremio.hellfireae.com {
      import cloudflare-tls
      reverse_proxy 127.0.0.1:11470
    }
  '';
in
{
  virtualisation.oci-containers.containers.stremio-server = {
    image = "stremio/server:latest";
    ports = [ "11470:11470" ];
    volumes = [ "/var/lib/stremio-server:/root/.stremio-server" ];
    extraOptions = [ "--device=/dev/dri" ];
    environment = {
      NO_CORS = "1";
      CASTING_DISABLED = "1";
      LIBVA_DRIVER_NAME = "iHD";
    };
  };

  networking.firewall.allowedTCPPorts = [ 11470 ];

  # Caddy vhost — picked up by `import /var/www/html/*/caddyfile` in caddy.nix
  systemd.tmpfiles.rules = [
    "d /var/www/html/stremio 0755 root root -"
    "L+ /var/www/html/stremio/caddyfile - - - - ${caddyfile}"
  ];
}
