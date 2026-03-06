{ pkgs, ... }:

let
  caddyfile = pkgs.writeText "kimai-caddyfile" ''
    crm.hellfireae.com {
      import cloudflare-tls
      bind 100.87.216.16
      reverse_proxy 127.0.0.1:8001
    }
  '';
in
{
  virtualisation.docker.enable = true;

  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    ensureDatabases = [ "kimai" ];
    ensureUsers = [
      {
        name = "kimai";
        ensurePermissions = { "kimai.*" = "ALL PRIVILEGES"; };
      }
    ];
    settings.mysqld = {
      # Allow connections from Docker bridge network
      bind-address = "0.0.0.0";
    };
  };

  # Grant TCP access with password (ensureUsers only creates socket-auth user).
  # initialScript runs once on first MySQL start.
  systemd.services.mysql-kimai-setup = {
    description = "Set up Kimai MySQL user for TCP access";
    after = [ "mysql.service" ];
    wants = [ "mysql.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      ExecStart = pkgs.writeShellScript "mysql-kimai-setup" ''
        ${pkgs.mariadb}/bin/mysql -e "
          CREATE USER IF NOT EXISTS 'kimai'@'%' IDENTIFIED BY 'kimai';
          GRANT ALL PRIVILEGES ON kimai.* TO 'kimai'@'%';
          FLUSH PRIVILEGES;
        "
      '';
    };
  };

  virtualisation.oci-containers = {
    backend = "docker";
    containers.kimai = {
      image = "kimai/kimai2:latest";
      ports = [ "127.0.0.1:8001:8001" ];
      extraOptions = [ "--add-host=host.docker.internal:host-gateway" ];
      environment = {
        DATABASE_URL = "mysql://kimai:kimai@host.docker.internal:3306/kimai?charset=utf8mb4&serverVersion=mariadb-10.11.0";
        TRUSTED_PROXIES = "127.0.0.1,172.17.0.0/16";
        TRUSTED_HOSTS = "crm.hellfireae.com";
      };
    };
  };

  # Caddy vhost — picked up by `import /var/www/html/*/caddyfile` in caddy.nix
  systemd.tmpfiles.rules = [
    "d /var/www/html/kimai 0755 root root -"
    "L+ /var/www/html/kimai/caddyfile - - - - ${caddyfile}"
  ];
}
