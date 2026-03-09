{ pkgs, config, ... }:

let
  opensandbox-server = pkgs.callPackage ../../pkgs/opensandbox-server {};

  # OpenClaw orchestrator config — scoped egress to opensandbox API + ollama only
  networkPolicy = builtins.toJSON {
    defaultAction = "deny";
    egress = [
      { action = "allow"; target = "host.docker.internal:8080"; }
      { action = "allow"; target = "host.docker.internal:11434"; }
    ];
  };
in
{
  # Orchestrator + agent workspace directories (persist across nixos-rebuild)
  systemd.tmpfiles.rules = [
    "d /var/lib/orchestrator 0755 root root -"
    # Wanda — the orchestrator's own identity and memory
    "d /var/lib/orchestrator/wanda 0755 root root -"
    "d /var/lib/orchestrator/wanda/memory 0755 root root -"
    # Child agents
    "d /var/lib/orchestrator/agents 0755 root root -"
    "d /var/lib/orchestrator/agents/coder 0755 root root -"
    "d /var/lib/orchestrator/agents/coder/memory 0755 root root -"
    "d /var/lib/orchestrator/agents/coder/skills 0755 root root -"
    "d /var/lib/orchestrator/agents/reviewer 0755 root root -"
    "d /var/lib/orchestrator/agents/reviewer/memory 0755 root root -"
    "d /var/lib/orchestrator/agents/reviewer/skills 0755 root root -"
    "d /var/lib/orchestrator/agents/deployer 0755 root root -"
    "d /var/lib/orchestrator/agents/deployer/memory 0755 root root -"
    "d /var/lib/orchestrator/agents/deployer/skills 0755 root root -"
    # Shared
    "d /var/lib/orchestrator/skills 0755 root root -"
    "d /var/lib/orchestrator/workflows 0755 root root -"
  ];

  # Seed personality + agent files (only if not already present — preserves growth)
  system.activationScripts.orchestrator-agents =
    let
      # Give each file a unique store name to avoid collisions
      wanda-identity = builtins.path { path = ../../wanda/IDENTITY.md; name = "wanda-IDENTITY.md"; };
      wanda-soul = builtins.path { path = ../../wanda/SOUL.md; name = "wanda-SOUL.md"; };
      wanda-user = builtins.path { path = ../../wanda/USER.md; name = "wanda-USER.md"; };
      wanda-personality = builtins.path { path = ../../wanda/personality.yaml; name = "wanda-personality.yaml"; };
      coder-soul = builtins.path { path = ../../agents/coder/SOUL.md; name = "coder-SOUL.md"; };
      coder-agents = builtins.path { path = ../../agents/coder/AGENTS.md; name = "coder-AGENTS.md"; };
      reviewer-soul = builtins.path { path = ../../agents/reviewer/SOUL.md; name = "reviewer-SOUL.md"; };
      reviewer-agents = builtins.path { path = ../../agents/reviewer/AGENTS.md; name = "reviewer-AGENTS.md"; };
      deployer-soul = builtins.path { path = ../../agents/deployer/SOUL.md; name = "deployer-SOUL.md"; };
      deployer-agents = builtins.path { path = ../../agents/deployer/AGENTS.md; name = "deployer-AGENTS.md"; };
      workflow = builtins.path { path = ../../workflows/wp-task.yaml; name = "wp-task.yaml"; };
    in {
    text = ''
      # Ensure directories exist (activation runs before tmpfiles)
      mkdir -p /var/lib/orchestrator/wanda/memory
      mkdir -p /var/lib/orchestrator/agents/{coder,reviewer,deployer}/{memory,skills}
      mkdir -p /var/lib/orchestrator/{skills,workflows}

      seed_file() {
        local dest="$1"
        local src="$2"
        if [ ! -f "$dest" ]; then
          cp "$src" "$dest"
          echo "Seeded $dest"
        fi
      }

      # Wanda — the orchestrator herself
      # These are the seed. She grows from here.
      seed_file /var/lib/orchestrator/wanda/IDENTITY.md ${wanda-identity}
      seed_file /var/lib/orchestrator/wanda/SOUL.md ${wanda-soul}
      seed_file /var/lib/orchestrator/wanda/USER.md ${wanda-user}
      seed_file /var/lib/orchestrator/wanda/personality.yaml ${wanda-personality}

      # Wanda's memory starts empty — she fills it herself
      if [ ! -f /var/lib/orchestrator/wanda/MEMORY.md ]; then
        cat > /var/lib/orchestrator/wanda/MEMORY.md << 'SEED'
# MEMORY.md — Wanda

*This file is mine. I update it as I learn.*

## Patterns

## Preferences

## Lessons
SEED
        echo "Seeded /var/lib/orchestrator/wanda/MEMORY.md"
      fi

      # Coder agent
      seed_file /var/lib/orchestrator/agents/coder/SOUL.md ${coder-soul}
      seed_file /var/lib/orchestrator/agents/coder/AGENTS.md ${coder-agents}

      # Reviewer agent
      seed_file /var/lib/orchestrator/agents/reviewer/SOUL.md ${reviewer-soul}
      seed_file /var/lib/orchestrator/agents/reviewer/AGENTS.md ${reviewer-agents}

      # Deployer agent
      seed_file /var/lib/orchestrator/agents/deployer/SOUL.md ${deployer-soul}
      seed_file /var/lib/orchestrator/agents/deployer/AGENTS.md ${deployer-agents}

      # Seed workflow
      seed_file /var/lib/orchestrator/workflows/wp-task.yaml ${workflow}
    '';
  };

  # OpenClaw orchestrator — Wanda runs inside an OpenSandbox container
  systemd.services.orchestrator = {
    description = "Wanda — OpenClaw Orchestrator (containerized via OpenSandbox)";
    after = [ "opensandbox-server.service" "opensandbox-pull-images.service" "network-online.target" ];
    requires = [ "opensandbox-server.service" ];
    wants = [ "network-online.target" "opensandbox-pull-images.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      RestartSec = 10;
    };
    path = [ pkgs.curl pkgs.jq ];
    script = ''
      # Wait for OpenSandbox API to be ready
      for i in $(seq 1 30); do
        if curl -sf http://localhost:8080/health > /dev/null 2>&1; then
          break
        fi
        sleep 2
      done

      # Create orchestrator sandbox via OpenSandbox API
      # Wanda's identity + memory mounted alongside agent workspaces
      SANDBOX_ID=$(curl -sf -X POST http://localhost:8080/api/v1/sandboxes \
        -H 'Content-Type: application/json' \
        -d '{
          "image": "ghcr.io/openclaw/openclaw:latest",
          "network_policy": ${builtins.toJSON networkPolicy},
          "mounts": [
            {"source": "/var/lib/orchestrator/wanda", "target": "/home/user/.openclaw/identity"},
            {"source": "/var/lib/orchestrator/agents", "target": "/home/user/.openclaw/agents"},
            {"source": "/var/lib/orchestrator/skills", "target": "/home/user/.openclaw/skills"},
            {"source": "/var/lib/orchestrator/workflows", "target": "/home/user/.openclaw/workflows"}
          ],
          "ports": [{"host": 8100, "container": 8100}]
        }' | jq -r '.id')

      if [ -z "$SANDBOX_ID" ] || [ "$SANDBOX_ID" = "null" ]; then
        echo "Failed to create orchestrator sandbox"
        exit 1
      fi

      echo "Wanda is awake (sandbox: $SANDBOX_ID)"

      # Keep service alive — sandbox lifecycle managed by OpenSandbox
      # Poll sandbox health until it exits
      while true; do
        STATUS=$(curl -sf "http://localhost:8080/api/v1/sandboxes/$SANDBOX_ID" | jq -r '.status' 2>/dev/null)
        if [ "$STATUS" != "running" ] && [ "$STATUS" != "starting" ]; then
          echo "Wanda stopped (status: $STATUS)"
          exit 1
        fi
        sleep 30
      done
    '';
  };

  # Firewall — expose orchestrator API on Tailscale
  networking.firewall.allowedTCPPorts = [ 8100 ];
}
