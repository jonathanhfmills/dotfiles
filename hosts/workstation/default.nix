{ pkgs, ... }:

{
  imports = [
    ./hardware.nix
    ./disko.nix
  ];

  # Hostname.
  networking.hostName = "workstation";

  # LTS kernel — required for ZFS compatibility.
  boot.kernelPackages = pkgs.linuxPackages;

  # ZFS support (mirror pool across 2x NVMe drives).
  boot.supportedFilesystems = [ "zfs" ];
  boot.kernelParams = [ "zfs.zfs_arc_max=4294967296" ];  # 4 GB
  networking.hostId = "2f50e4ce";

  # AMD GPU hardware acceleration.
  hardware.graphics.enable = true;

  # Headless by default — no display manager or desktop environment.
  # Gamescope + Steam can be launched on HDMI via SSH.

  # Seat management (required for gamescope DRM access from SSH).
  services.seatd.enable = true;

  # PipeWire audio (needed for Sunshine streaming + local output).
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # User accounts.
  users.users.jon = {
    isNormalUser = true;
    description = "Jonathan Mills";
    extraGroups = [ "networkmanager" "wheel" "input" "video" "seat" ];
    linger = true;  # Start user services (Sunshine) at boot without login.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMI/v0grXNp+qVV8TUky2BiHjHFpid6XCAA3Pg5G958Z jon@nixos-fleet"
    ];
  };

  # Steam with gamescope session.
  programs.steam.enable = true;
  programs.steam.gamescopeSession.enable = true;
  programs.steam.extraPackages = [
    # "Exit to Desktop" calls steamos-session-select inside bwrap.
    # Signal the wrapper via a flag file (bwrap shares /run).
    (pkgs.writeShellScriptBin "steamos-session-select" ''
      touch /run/user/1000/exit-gamescope
    '')
  ];
  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };

  # Sway headless compositor — virtual display for Sunshine streaming.
  # Sway creates a GPU-backed virtual output; Sunshine captures via wlr protocol.
  programs.sway.enable = true;
  systemd.user.services.sway-headless = {
    description = "Sway headless compositor for Sunshine";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.writeShellScript "sway-sunshine-start" ''
        # Clean stale wayland sockets from previous sessions.
        rm -f "$XDG_RUNTIME_DIR"/wayland-*
        # Launch sway with headless virtual display.
        /run/current-system/sw/bin/sway -c ${pkgs.writeText "sway-headless.conf" ''
          output HEADLESS-1 resolution 1920x1080@60Hz
          for_window [app_id="gamescope"] fullscreen enable
        ''} &
        SWAY_PID=$!
        # Wait for sway to create its wayland socket.
        for i in $(seq 1 50); do
          for sock in "$XDG_RUNTIME_DIR"/wayland-*; do
            if [ -S "$sock" ]; then
              export WAYLAND_DISPLAY=$(basename "$sock")
              break 2
            fi
          done
          sleep 0.1
        done
        # Make WAYLAND_DISPLAY and GPU env available to other user services, then start Sunshine.
        export LIBVA_DRIVER_NAME=radeonsi
        /run/current-system/sw/bin/systemctl --user import-environment WAYLAND_DISPLAY LIBVA_DRIVER_NAME
        /run/current-system/sw/bin/systemctl --user start sunshine
        wait $SWAY_PID
      ''}";
      Restart = "on-failure";
      RestartSec = 3;
    };
    environment = {
      WLR_BACKENDS = "headless";
      WLR_RENDERER = "gles2";
      WLR_LIBINPUT_NO_DEVICES = "1";
      XDG_SESSION_TYPE = "wayland";
      XDG_CURRENT_DESKTOP = "sway";
    };
  };

  # Sunshine — always-on remote desktop with AV1 hardware encoding.
  # Runs inside sway-headless; captures virtual display via wlr protocol.
  services.sunshine = {
    enable = true;
    autoStart = false;  # Started by sway-headless compositor.
    capSysAdmin = true;
    openFirewall = true;
    settings = {
      capture = "wlr";
      adapter_name = "/dev/dri/renderD129";
    };
    applications = {
      apps = [
        {
          name = "Steam";
          cmd = "/run/current-system/sw/bin/steam -gamepadui -steamos3 -steampal -steamdeck";
          image-path = "steam.png";
        }
        {
          name = "Desktop";
          image-path = "desktop.png";
        }
      ];
    };
  };

  # Gamescope + Steam as a systemd service on VT2 (needs seat/DRM access).
  systemd.services.gamescope-steam = {
    description = "Steam Big Picture via Gamescope";
    conflicts = [ "getty@tty2.service" ];
    after = [ "systemd-logind.service" ];
    serviceConfig = {
      User = "jon";
      Group = "users";
      PAMName = "login";
      TTYPath = "/dev/tty2";
      StandardInput = "tty-force";
      StandardOutput = "journal";
      StandardError = "journal";
      Restart = "no";
      ExecStart = "${pkgs.writeShellScript "gamescope-steam-wrapper" ''
        rm -f /run/user/1000/exit-gamescope
        rm -f /tmp/steamos-reboot-sentinel /tmp/steamos-shutdown-sentinel
        ${pkgs.gamescope}/bin/gamescope -e --backend drm -- steam -gamepadui -steamos3 -steampal -steamdeck &
        GAMESCOPE_PID=$!
        # Poll for the exit flag (set by steamos-session-select inside bwrap)
        # or reboot/shutdown sentinels written directly by Steam.
        while true; do
          [ -f /run/user/1000/exit-gamescope ] && break
          [ -f /tmp/steamos-reboot-sentinel ] && break
          [ -f /tmp/steamos-shutdown-sentinel ] && break
          kill -0 $GAMESCOPE_PID 2>/dev/null || break
          sleep 1
        done
        kill $GAMESCOPE_PID 2>/dev/null
        wait $GAMESCOPE_PID 2>/dev/null
        # Handle sentinel actions.
        if [ -f /tmp/steamos-reboot-sentinel ]; then
          rm -f /tmp/steamos-reboot-sentinel
          systemctl reboot
        elif [ -f /tmp/steamos-shutdown-sentinel ]; then
          rm -f /tmp/steamos-shutdown-sentinel
          systemctl poweroff
        fi
        rm -f /run/user/1000/exit-gamescope
      ''}";
    };
    environment = {
      XDG_RUNTIME_DIR = "/run/user/1000";
    };
    wantedBy = [];  # Started on demand via `session` command.
  };

  # Session switcher — manage local HDMI output over SSH.
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "session" ''
      case "''${1:-status}" in
        steam)
          sudo systemctl start gamescope-steam
          echo "Steam Big Picture started on HDMI"
          ;;
        stop)
          sudo systemctl stop gamescope-steam 2>/dev/null
          echo "Local display stopped (headless)"
          ;;
        status)
          echo "sway:      $(systemctl --user is-active sway-headless 2>/dev/null || echo stopped)"
          echo "sunshine:  $(systemctl --user is-active sunshine 2>/dev/null || echo stopped)"
          echo "gamescope: $(systemctl is-active gamescope-steam 2>/dev/null)"
          ;;
        *)
          echo "Usage: session {steam|stop|status}"
          echo ""
          echo "  steam   — Steam Big Picture on HDMI"
          echo "  stop    — Kill local display (headless)"
          echo "  status  — Show what's running"
          ;;
      esac
    '')
  ];

  # OpenSSH (Tailscale only) — always available regardless of session mode.
  services.openssh = {
    enable = true;
    listenAddresses = [
      { addr = "100.95.201.10"; port = 22; }
    ];
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };
  systemd.services.sshd = {
    after = [ "tailscaled.service" ];
    wants = [ "tailscaled.service" ];
    serviceConfig.RestartSec = 5;
  };
}
