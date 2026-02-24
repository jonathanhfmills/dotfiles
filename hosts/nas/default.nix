{ pkgs, ... }:

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
  networking.hostId = "c1192ca0";

  # Headless server — no display manager, desktop, or gaming stack.

  # Seat management.
  services.seatd.enable = true;

  # User accounts.
  users.users.jon = {
    isNormalUser = true;
    description = "Jonathan Mills";
    extraGroups = [ "networkmanager" "wheel" "video" ];
    linger = true;
    hashedPasswordFile = "/etc/nixos/password-jon";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMI/v0grXNp+qVV8TUky2BiHjHFpid6XCAA3Pg5G958Z jon@nixos-fleet"
    ];
  };

  # OpenSSH (Tailscale only) — update listenAddresses after Tailscale join.
  services.openssh = {
    enable = true;
    listenAddresses = [
      { addr = "100.103.206.89"; port = 22; }
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
