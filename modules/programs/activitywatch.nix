{ pkgs, config, ... }:
let
  hostname = config.networking.hostName;
  hasDisplay = builtins.elem hostname [ "desktop" "laptop" ];
  isWorkstation = hostname == "workstation";
in
{
  home-manager.users.jon = {
    services.activitywatch = {
      enable = true;
      package = pkgs.aw-server-rust;
      watchers = {
        aw-watcher-afk.package = pkgs.aw-watcher-afk;
      } // (if hasDisplay then {
        aw-watcher-window.package = pkgs.aw-watcher-window;
      } else {});
    };
  };

  # Linger on workstation so user services start at boot (headless).
  systemd.tmpfiles.rules = pkgs.lib.optionals isWorkstation [
    "f /var/lib/systemd/linger/jon"
  ];
}
