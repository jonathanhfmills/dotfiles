{ pkgs, ... }:

{
  imports = [
    ./hardware.nix
    ./disko.nix
  ];

  # Hostname.
  networking.hostName = "portable";

  # User accounts.
  users.users.jon = {
    isNormalUser = true;
    description = "Jonathan Mills";
    extraGroups = [ "networkmanager" "wheel" ];
    initialPassword = "changeme";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMI/v0grXNp+qVV8TUky2BiHjHFpid6XCAA3Pg5G958Z jon@nixos-fleet"
    ];
  };

  # OpenSSH.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };
}
