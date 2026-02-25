{ ... }:

{
  # Disable systemd-resolved stub listener (conflicts with port 53).
  services.resolved.extraConfig = "DNSStubListener=no";

  # Point the host's own DNS at the local dnscrypt-proxy.
  networking.nameservers = [ "127.0.0.1" ];

  # Ensure dnscrypt-proxy starts before anything that needs DNS.
  systemd.services.dnscrypt-proxy = {
    before = [ "network-online.target" "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
  };

  services.dnscrypt-proxy = {
    enable = true;

    settings = {
      listen_addresses = [ "0.0.0.0:53" ];

      # Cloudflare DoH primary, Google DoH backup.
      server_names = [ "cloudflare" "google" ];

      # Only use DNS-over-HTTPS.
      doh_servers = true;
      dnscrypt_servers = false;
      odoh_servers = false;

      # Require DNSSEC and no-logging.
      require_dnssec = true;
      require_nofilter = true;
      require_nolog = true;

      # Bootstrap resolvers (plain DNS) — used to resolve DoH server hostnames
      # and download the resolver list on first boot.
      bootstrap_resolvers = [ "1.1.1.1:53" "8.8.8.8:53" ];
      fallback_resolvers = [ "1.1.1.1:53" "8.8.8.8:53" ];

      # Upstream source list for resolvers.
      sources.public-resolvers = {
        urls = [
          "https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/public-resolvers.md"
          "https://download.dnscrypt.info/resolvers-list/v3/public-resolvers.md"
        ];
        cache_file = "/var/lib/dnscrypt-proxy/public-resolvers.md";
        minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3";
      };

      # No IPv6 on the LAN — skip AAAA lookups.
      block_ipv6 = true;

      # Performance tuning.
      cache = true;
      cache_size = 4096;
      cache_min_ttl = 600;
      cache_max_ttl = 86400;
    };
  };

  # DNS ports.
  networking.firewall.allowedTCPPorts = [ 53 ];
  networking.firewall.allowedUDPPorts = [ 53 ];
}
