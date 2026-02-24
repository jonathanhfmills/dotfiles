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
  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };

  # Sunshine — always-on remote desktop with AV1 hardware encoding.
  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
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
      ExecStart = "${pkgs.gamescope}/bin/gamescope -e --backend drm -- steam -gamepadui";
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
          echo "gamescope: $(systemctl is-active gamescope-steam 2>/dev/null)"
          echo "sunshine:  $(systemctl --user is-active sunshine 2>/dev/null || echo stopped)"
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
