{ pkgs, config, lib, ... }:
let
  hostname = config.networking.hostName;
  hasDisplay = builtins.elem hostname [ "desktop" "laptop" ];
  isHeadless = builtins.elem hostname [ "workstation" "nas" ];
  isNas = hostname == "nas";
  awPackage = pkgs.aw-server-rust;
  awWatcherWindowCosmic = pkgs.aw-watcher-window-cosmic;
  awWatcherScreenshot = pkgs.aw-watcher-screenshot-linux;

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
      watchers = {
        aw-watcher-afk.package = pkgs.aw-watcher-afk;
      };
    };

    # COSMIC window watcher (replaces aw-watcher-window on GUI hosts).
    systemd.user.services.aw-watcher-window-cosmic = lib.mkIf hasDisplay {
      Unit = {
        Description = "ActivityWatch window watcher for COSMIC desktop";
        After = [ "activitywatch.service" ];
        BindsTo = [ "activitywatch.target" ];
      };
      Service = {
        ExecStart = "${awWatcherWindowCosmic}/bin/aw-watcher-window-cosmic";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = [ "activitywatch.target" ];
    };

    # Screenshot watcher — captures on window change, Wayland-native.
    systemd.user.services.aw-watcher-screenshot-linux = lib.mkIf hasDisplay {
      Unit = {
        Description = "ActivityWatch screenshot watcher (Linux)";
        After = [ "activitywatch.service" "aw-watcher-window-cosmic.service" ];
        BindsTo = [ "activitywatch.target" ];
      };
      Service = {
        ExecStart = "${awWatcherScreenshot}/bin/aw-watcher-screenshot-linux";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = [ "activitywatch.target" ];
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

  # Chrome extension: ActivityWatch Web Watcher (installed via policy).
  programs.chromium.extensions = lib.mkIf hasDisplay [
    "nglaklhklhcoonedhgnpgddginnjdadi" # aw-watcher-web
  ];

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
