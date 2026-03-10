{ pkgs, config, lib, ... }:

let
  hostname = config.networking.hostName;
  isNas = hostname == "nas";

  opensandbox-server = pkgs.callPackage ../../pkgs/opensandbox-server {};

  # Air-gapped network policy: ONLY filesystem (queue writes) + localhost ollama
  # NO opensandbox API access — Wanda never spawns sandboxes directly
  networkPolicy = builtins.toJSON {
    defaultAction = "deny";
    egress = [
      { action = "allow"; target = "host.docker.internal:11434"; }
    ];
  };
in
lib.mkIf isNas {
  # Orchestrator + shared queue directory structure (persists across nixos-rebuild)
  systemd.tmpfiles.rules = [
    "d /var/lib/orchestrator 0755 root root -"
    # Wanda — the orchestrator's own identity and memory
    "d /var/lib/orchestrator/wanda 0755 root root -"
    "d /var/lib/orchestrator/wanda/memory 0755 root root -"
    # Shared queue structure — Syncthing syncs this between NAS and workstation
    "d /var/lib/orchestrator/shared 0755 root root -"
    "d /var/lib/orchestrator/shared/queue 0755 root root -"
    "d /var/lib/orchestrator/shared/queue/nas 0755 root root -"
    "d /var/lib/orchestrator/shared/queue/workstation 0755 root root -"
    "d /var/lib/orchestrator/shared/queue/results 0755 root root -"
    "d /var/lib/orchestrator/shared/skills 0755 root root -"
    "d /var/lib/orchestrator/shared/escalation-log 0755 root root -"
    "d /var/lib/orchestrator/shared/escalation-log/coding 0755 root root -"
    "d /var/lib/orchestrator/shared/escalation-log/review 0755 root root -"
    "d /var/lib/orchestrator/shared/escalation-log/writing 0755 root root -"
    "d /var/lib/orchestrator/shared/escalation-log/research 0755 root root -"
    # Workflow storage
    "d /var/lib/orchestrator/workflows 0755 root root -"
  ];

  # Seed Wanda's identity + workflow files (only if not already present — preserves growth)
  system.activationScripts.orchestrator-seed =
    let
      wanda-identity = builtins.path { path = ../../wanda/IDENTITY.md; name = "wanda-IDENTITY.md"; };
      wanda-soul = builtins.path { path = ../../wanda/SOUL.md; name = "wanda-SOUL.md"; };
      wanda-user = builtins.path { path = ../../wanda/USER.md; name = "wanda-USER.md"; };
      wanda-personality = builtins.path { path = ../../wanda/personality.yaml; name = "wanda-personality.yaml"; };
      wf-dispatch = builtins.path { path = ../../workflows/dispatch.yaml; name = "dispatch.yaml"; };
      wf-escalation = builtins.path { path = ../../workflows/escalation.yaml; name = "escalation.yaml"; };
      wf-content = builtins.path { path = ../../workflows/content-task.yaml; name = "content-task.yaml"; };
      wf-research = builtins.path { path = ../../workflows/research-task.yaml; name = "research-task.yaml"; };
      wf-wp = builtins.path { path = ../../workflows/wp-task.yaml; name = "wp-task.yaml"; };
    in {
    text = ''
      mkdir -p /var/lib/orchestrator/wanda/memory
      mkdir -p /var/lib/orchestrator/shared/queue/{nas,workstation,results}
      mkdir -p /var/lib/orchestrator/shared/{skills,escalation-log/{coding,review,writing,research}}
      mkdir -p /var/lib/orchestrator/workflows

      seed_file() {
        local dest="$1"
        local src="$2"
        if [ ! -f "$dest" ]; then
          cp "$src" "$dest"
          echo "Seeded $dest"
        fi
      }

      # Wanda — the orchestrator herself
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

      # Lobster workflow files
      seed_file /var/lib/orchestrator/workflows/dispatch.yaml ${wf-dispatch}
      seed_file /var/lib/orchestrator/workflows/escalation.yaml ${wf-escalation}
      seed_file /var/lib/orchestrator/workflows/content-task.yaml ${wf-content}
      seed_file /var/lib/orchestrator/workflows/research-task.yaml ${wf-research}
      seed_file /var/lib/orchestrator/workflows/wp-task.yaml ${wf-wp}
    '';
  };

  # OpenClaw orchestrator — Wanda runs inside an OpenSandbox container
  # AIR-GAPPED: only filesystem queue writes + localhost:11434 (ollama)
  # NO opensandbox API access — agent-runner handles sandbox spawning
  systemd.services.orchestrator = {
    description = "Wanda — OpenClaw Orchestrator (NAS, air-gapped)";
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
      # Air-gap: Wanda can ONLY write to the shared queue dir + talk to local ollama
      # She CANNOT access the opensandbox API from inside the sandbox
      SANDBOX_ID=$(curl -sf -X POST http://localhost:8080/v1/sandboxes \
        -H 'Content-Type: application/json' \
        -d '{
          "image": {"uri": "ghcr.io/openclaw/openclaw:latest"},
          "timeout": 86400,
          "resourceLimits": {"cpu": "1000m", "memory": "2Gi"},
          "entrypoint": ["openclaw", "gateway", "run", "--port", "8100", "--allow-unconfigured", "--auth", "none", "--bind", "loopback"],
          "networkPolicy": ${networkPolicy},
          "volumes": [
            {"name": "wanda-identity", "host": {"path": "/var/lib/orchestrator/wanda"}, "mountPath": "/home/user/.openclaw/identity"},
            {"name": "shared-queue", "host": {"path": "/var/lib/orchestrator/shared"}, "mountPath": "/home/user/.openclaw/shared"},
            {"name": "workflows", "host": {"path": "/var/lib/orchestrator/workflows"}, "mountPath": "/home/user/.openclaw/workflows"}
          ]
        }' | jq -r '.id')

      if [ -z "$SANDBOX_ID" ] || [ "$SANDBOX_ID" = "null" ]; then
        echo "Failed to create orchestrator sandbox"
        exit 1
      fi

      echo "Wanda is awake (sandbox: $SANDBOX_ID)"

      # Keep service alive — poll sandbox health + renew expiration
      while true; do
        STATUS=$(curl -sf "http://localhost:8080/v1/sandboxes/$SANDBOX_ID" | jq -r '.status.state' 2>/dev/null)
        if [ "$STATUS" != "Running" ] && [ "$STATUS" != "Pending" ]; then
          echo "Wanda stopped (status: $STATUS)"
          exit 1
        fi
        # Renew expiration to keep sandbox alive (24h rolling)
        EXPIRES=$(date -u -d '+24 hours' '+%Y-%m-%dT%H:%M:%SZ')
        curl -sf -X POST "http://localhost:8080/v1/sandboxes/$SANDBOX_ID/renew-expiration" \
          -H 'Content-Type: application/json' \
          -d "{\"expiresAt\": \"$EXPIRES\"}" > /dev/null 2>&1
        sleep 30
      done
    '';
  };

  # Firewall — expose orchestrator API on Tailscale
  networking.firewall.allowedTCPPorts = [ 8100 ];
}
