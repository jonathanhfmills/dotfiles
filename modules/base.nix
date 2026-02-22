{ pkgs, ... }:

{
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Enable flakes and the nix command.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

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
