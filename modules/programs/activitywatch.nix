{ pkgs, config, lib, ... }:
let
  hostname = config.networking.hostName;
  hasDisplay = builtins.elem hostname [ "desktop" "laptop" ];
  isHeadless = builtins.elem hostname [ "workstation" "nas" ];
  isNas = hostname == "nas";
  awPackage = pkgs.aw-server-rust;
  awWatcherWindowWayland = pkgs.aw-watcher-window-wayland;
  awWatcherScreenshot = pkgs.aw-watcher-screenshot-linux;
  awWatcherInput = pkgs.aw-watcher-input;
  awNotify = pkgs.aw-notify;
  awAndroidAdb = pkgs.aw-android-adb;

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
      # On display hosts, aw-watcher-window-wayland handles both window and AFK.
      # On headless hosts, only aw-watcher-afk is needed (no Wayland display).
      watchers = lib.mkIf (!hasDisplay) {
        aw-watcher-afk.package = pkgs.aw-watcher-afk;
      };
    };

    # Wayland window + AFK watcher — single binary replaces both
    # aw-watcher-window-cosmic and aw-watcher-afk on GUI hosts.
    # Uses wlr-foreign-toplevel-management (Sway/Hyprland) with
    # zcosmic_toplevel_info_v1 fallback (COSMIC desktop).
    systemd.user.services.aw-watcher-window-wayland = lib.mkIf hasDisplay {
      Unit = {
        Description = "ActivityWatch window and AFK watcher (Wayland)";
        After = [ "activitywatch.service" ];
        BindsTo = [ "activitywatch.target" ];
      };
      Service = {
        ExecStart = "${awWatcherWindowWayland}/bin/aw-watcher-window-wayland";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = [ "activitywatch.target" ];
    };

    # Screenshot watcher — captures on window change, Wayland-native.
    systemd.user.services.aw-watcher-screenshot-linux = lib.mkIf hasDisplay {
      Unit = {
        Description = "ActivityWatch screenshot watcher (Linux)";
        After = [ "activitywatch.service" "aw-watcher-window-wayland.service" ];
        BindsTo = [ "activitywatch.target" ];
      };
      Service = {
        ExecStart = "${awWatcherScreenshot}/bin/aw-watcher-screenshot-linux";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = [ "activitywatch.target" ];
    };

    # Input watcher — tracks keypress and mouse movement counts (not a keylogger).
    # Needs the `input` group for /dev/input access.
    systemd.user.services.aw-watcher-input = lib.mkIf hasDisplay {
      Unit = {
        Description = "ActivityWatch input watcher (keypresses and mouse movements)";
        After = [ "activitywatch.service" ];
        BindsTo = [ "activitywatch.target" ];
      };
      Service = {
        ExecStart = "${awWatcherInput}/bin/aw-watcher-input";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = [ "activitywatch.target" ];
    };

    # Screentime notifications — "You've been on X for 30min", end-of-day summaries.
    systemd.user.services.aw-notify = lib.mkIf hasDisplay {
      Unit = {
        Description = "ActivityWatch screentime notifications";
        After = [ "activitywatch.service" ];
        BindsTo = [ "activitywatch.target" ];
      };
      Service = {
        ExecStart = "${awNotify}/bin/aw-notify start";
        Restart = "on-failure";
        RestartSec = 10;
      };
      Install.WantedBy = [ "activitywatch.target" ];
    };

    # aw-client CLI — query buckets, events, reports from the terminal.
    home.packages = lib.mkIf hasDisplay [
      pkgs.python3Packages.aw-client
    ];

    # Android app usage via ADB — pulls from phone over Tailscale, pushes to aw-server.
    systemd.user.services.aw-android-adb = lib.mkIf hasDisplay {
      Unit = {
        Description = "ActivityWatch Android watcher via ADB";
        After = [ "activitywatch.service" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${awAndroidAdb}/bin/aw-android-adb sync --device-name phone";
      };
    };
    systemd.user.timers.aw-android-adb = lib.mkIf hasDisplay {
      Unit.Description = "Run aw-android-adb every 6 hours";
      Timer = {
        OnCalendar = "*-*-* 00/6:00:00";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
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
