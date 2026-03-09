{ pkgs, config, ... }:

let
  opensandbox-server = pkgs.callPackage ../../pkgs/opensandbox-server {};

  configFile = pkgs.writeText "sandbox.toml" ''
    [server]
    host = "0.0.0.0"
    port = 8080
    log_level = "INFO"

    [runtime]
    type = "docker"
    execd_image = "opensandbox/execd:v1.0.6"

    [egress]
    image = "opensandbox/egress:v1.0.1"

    [storage]
    allowed_host_paths = []

    [docker]
    network_mode = "bridge"
    drop_capabilities = ["AUDIT_WRITE", "MKNOD", "NET_ADMIN", "NET_RAW", "SYS_ADMIN", "SYS_MODULE", "SYS_PTRACE", "SYS_TIME", "SYS_TTY_CONFIG"]
    no_new_privileges = true
    apparmor_profile = ""
    pids_limit = 512
    seccomp_profile = ""

    [ingress]
    mode = "direct"
  '';
in
{
  # Docker runtime required by OpenSandbox
  virtualisation.docker.enable = true;

  # Add jon to docker group
  users.users.jon.extraGroups = [ "docker" ];

  systemd.services.opensandbox-server = {
    description = "OpenSandbox server";
    after = [ "docker.service" "network-online.target" ];
    requires = [ "docker.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${opensandbox-server}/bin/opensandbox-server --config ${configFile}";
      Restart = "on-failure";
      RestartSec = 5;
      DynamicUser = false;
    };
    environment = {
      SANDBOX_CONFIG_PATH = "${configFile}";
    };
  };

  # Pre-pull nullclaw container image
  systemd.services.opensandbox-pull-images = {
    description = "Pre-pull OpenSandbox container images";
    after = [ "docker.service" ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [ pkgs.docker ];
    script = ''
      docker pull ghcr.io/nullclaw/nullclaw:latest || true
      docker pull opensandbox/execd:v1.0.6 || true
      docker pull opensandbox/egress:v1.0.1 || true
    '';
  };

  # Firewall — expose OpenSandbox API on Tailscale
  networking.firewall.allowedTCPPorts = [ 8080 ];
}
