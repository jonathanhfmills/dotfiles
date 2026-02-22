{ pkgs, ... }:

{
  imports = [
    ./hardware.nix
  ];

  # Hostname.
  networking.hostName = "desktop";

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # AMD GPU hardware acceleration.
  hardware.graphics.enable = true;

  # COSMIC Desktop Environment.
  services.desktopManager.cosmic.enable = true;
  services.displayManager.cosmic-greeter.enable = true;
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "jon";
  services.system76-scheduler.enable = true;

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
  };

  users.users.cosmick = {
    isNormalUser = true;
    description = "Cosmick Dev";
    extraGroups = [ "networkmanager" "wheel" ];
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

  # Ollama.
  services.ollama.enable = true;

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
