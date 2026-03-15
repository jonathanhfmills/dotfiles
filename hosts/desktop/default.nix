{ config, pkgs, ... }:

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
  boot.kernelParams = [ "zfs.zfs_arc_max=2147483648" ];  # 2 GB
  networking.hostId = "726f84c0";

  # ZFS maintenance.
  services.zfs.autoScrub.enable = true;
  services.zfs.trim.enable = true;

  # CPU frequency governor.
  powerManagement.cpuFreqGovernor = "powersave";

  # GPU hardware acceleration (Intel iGPU for display, NVIDIA for compute when present).
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

  # GoXLR — udev rules, XDG autostart, goxlr-daemon + goxlr-client.
  services.goxlr-utility.enable = true;

  # CUPS printing.
  services.printing.enable = true;

  # Secrets.
  age.secrets.password-jon.file = ../../secrets/password-jon.age;

  # User accounts.
  users.users.jon = {
    isNormalUser = true;
    description = "Jonathan Mills";
    extraGroups = [ "networkmanager" "wheel" "input" ];
    hashedPasswordFile = config.age.secrets.password-jon.path;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMI/v0grXNp+qVV8TUky2BiHjHFpid6XCAA3Pg5G958Z jon@nixos-fleet"
    ];
  };

  users.users.jon-private = {
    isNormalUser = true;
    description = "Jon (Private)";
    extraGroups = [ "networkmanager" "video" "audio" "input" ];
    hashedPasswordFile = config.age.secrets.password-jon.path;
  };

  # Fonts.
  fonts.packages = with pkgs; [
    inter
    source-code-pro
  ];

  # GUI apps.
  environment.systemPackages = with pkgs; [
    discord
    (google-chrome.override { commandLineArgs = "--enable-features=AcceleratedVideoEncoder --ignore-gpu-blocklist"; })
    github-desktop
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


  # OpenSSH — available on all interfaces (LAN + Tailscale).
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };
}
