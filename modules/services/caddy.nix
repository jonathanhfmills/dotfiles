{ pkgs, config, ... }:

{
  services.caddy = {
    enable = true;

    package = pkgs.caddy.withPlugins {
      plugins = [ "github.com/caddy-dns/cloudflare@v0.2.3" ];
      hash = "sha256-eDCHOuPm+o3mW7y8nSaTnabmB/msw6y2ZUoGu56uvK0=";
    };

    environmentFile = config.age.secrets.caddy-cloudflare-token.path;

    # Reusable TLS snippet — services and static sites import this.
    extraConfig = ''
      (cloudflare-tls) {
        tls {
          dns cloudflare {$CF_API_TOKEN}
          resolvers 1.1.1.1
        }
      }

      import /var/www/html/*/caddyfile
    '';
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
