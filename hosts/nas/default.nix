{ config, pkgs, ... }:

{
  imports = [
    ./hardware.nix
    ./disko.nix
  ];

  # Hostname.
  networking.hostName = "nas";

  # LTS kernel — required for ZFS compatibility.
  boot.kernelPackages = pkgs.linuxPackages;

  # ZFS support (single 990 PRO — 980 PRO can mirror once firmware is fixed).
  boot.supportedFilesystems = [ "zfs" ];
  boot.kernelParams = [ "zfs.zfs_arc_max=12884901888" ];  # 12 GB
  networking.hostId = "c1192ca0";

  # Headless server — no display manager, desktop, or gaming stack.

  # Seat management.
  services.seatd.enable = true;

  # Secrets.
  age.secrets.password-jon.file = ../../secrets/password-jon.age;
  age.secrets.caddy-cloudflare-token.file = ../../secrets/caddy-cloudflare-token.age;

  # User accounts.
  users.users.jon = {
    isNormalUser = true;
    description = "Jonathan Mills";
    extraGroups = [ "networkmanager" "wheel" "video" ];
    linger = true;
    hashedPasswordFile = config.age.secrets.password-jon.path;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMI/v0grXNp+qVV8TUky2BiHjHFpid6XCAA3Pg5G958Z jon@nixos-fleet"
    ];
  };

  # OpenSSH — available on all interfaces (LAN + Tailscale).
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };
}
