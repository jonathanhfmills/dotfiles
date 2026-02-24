{ pkgs, ... }:

{
  imports = [
    ./hardware.nix
    ./disko.nix
  ];

  # Hostname.
  networking.hostName = "desktop";

  # LTS kernel — required for ZFS compatibility.
  boot.kernelPackages = pkgs.linuxPackages;

  # ZFS support (tools + kernel module, no ZFS filesystems required).
  boot.supportedFilesystems = [ "zfs" ];
  networking.hostId = "726f84c0";

  # GPU hardware acceleration.
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver    # Intel Quick Sync VA-API (iHD, Coffee Lake+)
      intel-vaapi-driver    # i965 fallback
      libvdpau-va-gl        # VDPAU via VA-API
    ];
  };

  # Raw input — no mouse acceleration.
  services.libinput.mouse.accelProfile = "flat";

  # COSMIC Desktop Environment.
  services.desktopManager.cosmic.enable = true;
  services.displayManager.cosmic-greeter.enable = true;
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "jon";
  services.system76-scheduler.enable = true;
  environment.cosmic.excludePackages = with pkgs; [
    cosmic-edit       # use VS Code
    cosmic-player     # not needed
    cosmic-store      # packages managed by nix
  ];

  # PipeWire audio.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # CUPS printing.
  services.printing.enable = true;

  # User accounts.
  users.users.jon = {
    isNormalUser = true;
    description = "Jonathan Mills";
    extraGroups = [ "networkmanager" "wheel" ];
    hashedPasswordFile = "/etc/nixos/password-jon";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMI/v0grXNp+qVV8TUky2BiHjHFpid6XCAA3Pg5G958Z jon@nixos-fleet"
    ];
  };

  # Fonts.
  fonts.packages = with pkgs; [
    inter
    source-code-pro
  ];

  # GUI apps.
  environment.systemPackages = with pkgs; [
    vscode
    discord
    google-chrome
    termius
    moonlight-qt
  ];

  # Steam with gamescope session.
  programs.steam.enable = true;
  programs.steam.gamescopeSession.enable = true;
  programs.steam.extraPackages = [
    (pkgs.writeShellScriptBin "steamos-session-select" ''
      steam -shutdown 2>/dev/null
      sleep 2
      kill $(pgrep -f steam-gamescope) 2>/dev/null
      kill $(pgrep gamescope) 2>/dev/null
    '')
  ];
  programs.gamescope.enable = true;


  # OpenSSH (Tailscale only).
  services.openssh = {
    enable = true;
    listenAddresses = [
      { addr = "100.74.117.36"; port = 22; }
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
