{ config, lib, ... }:
let
  hostname = config.networking.hostName;
  allDevices = {
    desktop     = { id = "KA3QJB4-VA34ODW-MI3ROX5-C23WKZU-L7W44UQ-XLEUZ5M-BQ7SHGE-EAYTJQV"; addresses = [ "tcp://100.92.6.103:22000" ]; };
    laptop      = { id = "TAMX5P4-JJAVZHR-6KYCP3G-SX4HNHJ-TVILTKQ-Z3ASFWN-WEU7VHC-OU65JAO"; addresses = [ "tcp://100.104.109.104:22000" ]; };
    nas         = { id = "PENDING-NAS-DEVICE-ID"; addresses = [ "tcp://100.87.216.16:22000" ]; };
    workstation = { id = "PENDING-WORKSTATION-DEVICE-ID"; addresses = [ "tcp://100.95.201.10:22000" ]; };
  };
  peerDevices = builtins.removeAttrs allDevices [ hostname ];
  peerNames = builtins.attrNames peerDevices;

  # Desktop/laptop hosts get user data folders; headless hosts only get ssh-config.
  guiHosts = [ "desktop" "laptop" ];
  isGui = builtins.elem hostname guiHosts;
  guiPeers = builtins.filter (n: builtins.elem n guiHosts) peerNames;

  mkFolder = id: path: devices: {
    inherit path id devices;
    type = "sendreceive";
  };
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
      folders = {
        ssh-config = mkFolder "ssh-config" "/home/jon/.ssh/config.d" peerNames;
      } // lib.optionalAttrs isGui {
        documents = mkFolder "documents" "/home/jon/Documents" guiPeers;
        pictures  = mkFolder "pictures"  "/home/jon/Pictures"  guiPeers;
        videos    = mkFolder "videos"    "/home/jon/Videos"    guiPeers;
        music     = mkFolder "music"     "/home/jon/Music"     guiPeers;
        desktop   = mkFolder "desktop"   "/home/jon/Desktop"   guiPeers;
      };
    };
  };

  # Syncthing traffic over Tailscale only.
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 22000 ];
  networking.firewall.interfaces."tailscale0".allowedUDPPorts = [ 21027 ];
}
