{ config, pkgs, ... }:

{
  imports = [
    ./hardware.nix
    ./disko.nix
  ];

  # Hostname.
  networking.hostName = "laptop";
  networking.hostId = "5e8b9eaa";

  # LTS kernel — required for ZFS compatibility.
  boot.kernelPackages = pkgs.linuxPackages;

  # ZFS support.
  boot.supportedFilesystems = [ "zfs" ];
  boot.kernelParams = [ "zfs.zfs_arc_max=1073741824" ];  # 1 GB

  # ZFS maintenance.
  services.zfs.autoScrub.enable = true;
  services.zfs.trim.enable = true;

  # Intel Iris Xe GPU hardware acceleration.
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver    # Intel Quick Sync VA-API (iHD, Tiger Lake+)
      intel-vaapi-driver    # i965 fallback
      libvdpau-va-gl        # VDPAU via VA-API
    ];
  };

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

  # Fingerprint authentication for sudo.
  security.pam.services.sudo.fprintAuth = true;

  # OpenSSH — available on all interfaces (LAN + Tailscale).
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };
}
