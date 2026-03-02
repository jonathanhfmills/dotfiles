{ config, pkgs, ... }:

{
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Enable flakes and the nix command.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Garbage collection — weekly, keep last 5 generations.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 5d";
  };

  # ZFS automatic monthly scrub (no-op on non-ZFS hosts).
  services.zfs.autoScrub.enable = true;

  # SSD TRIM — all hosts are on NVMe SSDs.
  services.fstrim.enable = true;

  # Firmware blobs (WiFi, Bluetooth, CPU microcode, etc.).
  hardware.enableRedistributableFirmware = true;

  # SSH host configs (fleet + client sites), encrypted with agenix.
  age.secrets.ssh-hosts = {
    file = ../secrets/ssh-hosts.age;
    owner = "jon";
    group = "users";
    mode = "0400";
  };

  # Timezone.
  time.timeZone = "America/New_York";

  # Locale.
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Passwordless sudo for wheel.
  security.sudo.wheelNeedsPassword = false;

  # Allow unfree packages.
  nixpkgs.config.allowUnfree = true;

  # Base CLI packages.
  environment.systemPackages = with pkgs; [
    git
    gh
    curl
    wget
    ripgrep
    fd
    jq
    tree
  ];

  system.stateVersion = "25.11";
}
