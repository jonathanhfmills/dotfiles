{ config, ... }:
let
  hostname = config.networking.hostName;
  allDevices = {
    desktop = { id = "664AMRB-2HYKAQS-OUON46U-TNCZWZ5-7VNQ5I7-FHO6FPY-424CVG3-2JSZXAI"; addresses = [ "tcp://100.92.6.103:22000" ]; };
    laptop  = { id = "TAMX5P4-JJAVZHR-6KYCP3G-SX4HNHJ-TVILTKQ-Z3ASFWN-WEU7VHC-OU65JAO"; addresses = [ "tcp://100.104.109.104:22000" ]; };
  };
  peerDevices = builtins.removeAttrs allDevices [ hostname ];
  peerNames = builtins.attrNames peerDevices;
in {
  services.syncthing = {
    enable = true;
    user = "jon";
    group = "users";
    dataDir = "/home/jon";
    overrideDevices = true;
    overrideFolders = true;
    settings = {
      devices = peerDevices;
      folders.home = {
        path = "/home/jon";
        id = "home";
        devices = peerNames;
        type = "sendreceive";
      };
    };
  };

  # Syncthing traffic over Tailscale only.
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 22000 ];
  networking.firewall.interfaces."tailscale0".allowedUDPPorts = [ 21027 ];
}
