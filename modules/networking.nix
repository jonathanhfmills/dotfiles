{ pkgs, config, ... }:

{
  networking.networkmanager.enable = true;
  services.tailscale.enable = true;
  services.tailscale.extraSetFlags = [ "--operator=jon" ];
  environment.systemPackages = [ pkgs.trayscale ];

  # WiFi PSK from agenix (decrypted at runtime)
  age.secrets.wifi-psk = {
    file = ../secrets/wifi-psk.age;
    owner = "root";
    group = "root";
    mode = "0600";
  };

  # Declarative NetworkManager profiles: ethernet preferred, WiFi fallback
  networking.networkmanager.ensureProfiles = {
    environmentFiles = [ config.age.secrets.wifi-psk.path ];
    profiles = {
      # Wired — highest priority, auto-connect whenever plugged in
      ethernet = {
        connection = {
          id = "Wired";
          type = "ethernet";
          autoconnect = "true";
          autoconnect-priority = "100";
        };
        ipv4.method = "auto";
        ipv6.method = "auto";
      };
      # WiFi — lower priority fallback
      wifi-young-5g = {
        connection = {
          id = "YOUNG-5G";
          type = "wifi";
          autoconnect = "true";
          autoconnect-priority = "10";
        };
        wifi = {
          ssid = "YOUNG-5G";
          mode = "infrastructure";
        };
        wifi-security = {
          key-mgmt = "wpa-psk";
          psk = "$WIFI_PSK";
        };
        ipv4.method = "auto";
        ipv6.method = "auto";
      };
    };
  };
}
