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

  # Tailscale: auto-authenticate with auth key so it connects unattended.
  # Generate a reusable key at https://login.tailscale.com/admin/settings/keys
  # Then: echo -n 'tskey-auth-...' | sudo tee /var/lib/tailscale/authkey
  # If the key file exists, tailscale up runs non-interactively on boot.
  systemd.services.tailscale-autoconnect = {
    description = "Automatic Tailscale connection";
    after = [ "network-online.target" "tailscaled.service" ];
    wants = [ "network-online.target" "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [ pkgs.tailscale pkgs.jq ];
    script = ''
      # Wait for tailscaled to be ready
      sleep 5

      # Already connected?
      STATUS=$(tailscale status --json 2>/dev/null | jq -r '.BackendState // empty')
      if [ "$STATUS" = "Running" ]; then
        echo "Tailscale already connected"
        exit 0
      fi

      # Try auth key if available
      if [ -f /var/lib/tailscale/authkey ]; then
        tailscale up --auth-key "$(cat /var/lib/tailscale/authkey)" --hostname portable
      else
        # No auth key — just bring it up (will need interactive auth first time)
        tailscale up --hostname portable
      fi
    '';
  };

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
