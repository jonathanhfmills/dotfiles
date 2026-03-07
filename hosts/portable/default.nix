{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware.nix
    ./disko.nix
  ];

  # Hostname.
  networking.hostName = "portable";

  # LTS kernel + ZFS — needed for provisioning ZFS hosts.
  boot.kernelPackages = pkgs.linuxPackages;
  boot.supportedFilesystems = [ "zfs" ];
  networking.hostId = "deadbeef";

  # Secrets.
  age.secrets.password-jon.file = ../../secrets/password-jon.age;

  # User accounts.
  users.users.jon = {
    isNormalUser = true;
    description = "Jonathan Mills";
    extraGroups = [ "networkmanager" "wheel" ];
    hashedPasswordFile = config.age.secrets.password-jon.path;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMI/v0grXNp+qVV8TUky2BiHjHFpid6XCAA3Pg5G958Z jon@nixos-fleet"
    ];
  };

  # Flash longevity — minimize writes to the USB SSD.
  boot.tmp.useTmpfs = true;                        # /tmp in RAM
  boot.tmp.tmpfsSize = "50%";                      # cap at half of RAM
  services.journald.extraConfig = ''
    SystemMaxUse=50M
    RuntimeMaxUse=50M
  '';
  nix.gc.automatic = lib.mkForce false;             # skip automatic GC on portable
  services.fstrim.enable = true;                   # periodic TRIM

  # Minimal X + VS Code — lightweight GUI for SSH remote and Claude extension.
  services.xserver.enable = true;
  services.xserver.windowManager.i3.enable = true;
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "jon";
  services.displayManager.defaultSession = "none+i3";
  environment.systemPackages = with pkgs; [ tmux ];

  # OpenSSH.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };
}
