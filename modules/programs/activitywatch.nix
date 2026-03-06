{ pkgs, config, lib, ... }:
let
  hostname = config.networking.hostName;
  hasDisplay = builtins.elem hostname [ "desktop" "laptop" ];
  isHeadless = builtins.elem hostname [ "workstation" "nas" ];
  isNas = hostname == "nas";
  awPackage = pkgs.aw-server-rust;

  caddyfile = pkgs.writeText "activitywatch-caddyfile" ''
    activity.hellfireae.com {
      import cloudflare-tls
      bind 100.87.216.16
      reverse_proxy 127.0.0.1:5600
    }
  '';
in
{
  home-manager.users.jon = {
    services.activitywatch = {
      enable = true;
      package = awPackage;
      watchers = (if isNas then {} else {
        aw-watcher-afk.package = pkgs.aw-watcher-afk;
      }) // (if hasDisplay then {
        aw-watcher-window.package = pkgs.aw-watcher-window;
      } else {});
    };

    # aw-sync daemon — exports local buckets to ~/ActivityWatchSync for Syncthing,
    # imports remote buckets from other devices.
    systemd.user.services.aw-sync = {
      Unit = {
        Description = "ActivityWatch sync daemon";
        After = [ "activitywatch.service" ];
        BindsTo = [ "activitywatch.target" ];
      };
      Service = {
        ExecStart = "${awPackage}/bin/aw-sync daemon";
        Restart = "on-failure";
        RestartSec = 10;
      };
      Install.WantedBy = [ "activitywatch.target" ];
    };
  };

  # Ensure AW data directory has correct ownership (needed for ZFS dataset mounts).
  systemd.tmpfiles.rules = [
    "d /home/jon/.local/share/activitywatch 0700 jon users -"
  ] ++ lib.optionals isHeadless [
    "f /var/lib/systemd/linger/jon"
  ] ++ lib.optionals isNas [
    "d /var/www/html/activitywatch 0755 root root -"
    "L+ /var/www/html/activitywatch/caddyfile - - - - ${caddyfile}"
  ];
}
