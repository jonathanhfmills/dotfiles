{ pkgs, ... }:

{
  networking.networkmanager.enable = true;
  services.tailscale.enable = true;
  environment.systemPackages = [ pkgs.trayscale ];
}
