# Hermes Agent — Brain tier orchestrator (NAS only)
# Runs inside an OpenSandbox container with deny-by-default network policy.
# Air-gapped: can only reach SGLang (inference) + OpenRouter (frontier).
# CANNOT reach OpenSandbox API — agent-runner handles sandbox spawning.
# All task routing happens via filesystem queue (mounted volumes).
#
# Identity: Wanda (IDENTITY.md, SOUL.md, USER.md, MEMORY.md)
# Rollback: swap import to orchestrator-openclaw.nix in flake.nix
{ pkgs, config, lib, ... }:

let
  hostname = config.networking.hostName;
  isNas = hostname == "nas";

  # Network policy: filesystem (queue writes) + SGLang + evaluator + frontier
  # NO opensandbox API access — Wanda never spawns sandboxes directly
  networkPolicy = builtins.toJSON {
    defaultAction = "deny";
    egress = [
      { action = "allow"; target = "172.17.0.1:11434"; }   # SGLang 9B (GPU)
      { action = "allow"; target = "172.17.0.1:11435"; }   # SGLang evaluator (CPU)
      { action = "allow"; target = "openrouter.ai:443"; }  # frontier escalation
      { action = "allow"; target = "pypi.org:443"; }       # pip install (hermes-agent)
      { action = "allow"; target = "files.pythonhosted.org:443"; }  # pip downloads
    ];
  };

  # MCP server scripts bundled into the container
  mcpDispatch = builtins.path { path = ../../pkgs/mcp-servers/dispatch.py; name = "dispatch.py"; };
  mcpEscalation = builtins.path { path = ../../pkgs/mcp-servers/escalation.py; name = "escalation.py"; };
  mcpMemory = builtins.path { path = ../../pkgs/mcp-servers/memory.py; name = "memory.py"; };
  mcpClawhub = builtins.path { path = ../../pkgs/mcp-servers/clawhub.py; name = "clawhub.py"; };
  hermesAdapter = builtins.path { path = ../../pkgs/hermes-agent/hermes-acp-adapter.py; name = "hermes-acp-adapter.py"; };

  # Hermes config — paths are container-internal
  # MCP servers run as child processes inside the container (same network policy)
  hermesConfig = builtins.toJSON {
    model = {
      default = "openai/Qwen/Qwen3.5-9B";
      provider = "auto";
    };
    terminal = {
      backend = "local";
      cwd = "/workspace/shared";
      timeout = 300;
    };
    mcp_servers = {
      dispatch = {
        command = "python3";
        args = [ "/opt/mcp-servers/dispatch.py" ];
      };
      escalation = {
        command = "python3";
        args = [ "/opt/mcp-servers/escalation.py" ];
      };
      memory = {
        command = "python3";
        args = [ "/opt/mcp-servers/memory.py" ];
      };
      clawhub = {
        command = "python3";
        args = [ "/opt/mcp-servers/clawhub.py" ];
      };
    };
  };

  # Entrypoint: queue-watching loop that routes tasks via SGLang OpenAI API
  # Standalone script avoids Nix quoting issues with bash/python in heredocs
  hermesEntrypoint = builtins.path { path = ../../pkgs/hermes-agent/entrypoint.sh; name = "hermes-entrypoint.sh"; };
in
lib.mkIf isNas {
  # Orchestrator directory structure (persists across nixos-rebuild)
  systemd.tmpfiles.rules = [
    "d /var/lib/orchestrator 0755 root root -"
    # Wanda — the Brain's identity and memory
    "d /var/lib/orchestrator/wanda 0755 root root -"
    "d /var/lib/orchestrator/wanda/memory 0755 root root -"
    # Hermes runtime (pip install cache, persists across container restarts)
    "d /var/lib/hermes 0755 root root -"
    "d /var/lib/hermes/lib 0755 root root -"
    # MCP server scripts (seeded from Nix, mounted into container)
    "d /var/lib/orchestrator/mcp-servers 0755 root root -"
    # Shared queue structure — Syncthing syncs this between NAS and workstation
    "d /var/lib/orchestrator/shared 0755 root root -"
    "d /var/lib/orchestrator/shared/queue 0755 root root -"
    "d /var/lib/orchestrator/shared/queue/nas 0755 root root -"
    "d /var/lib/orchestrator/shared/queue/workstation 0755 root root -"
    "d /var/lib/orchestrator/shared/queue/results 0755 root root -"
    "d /var/lib/orchestrator/shared/skills 0755 root root -"
    "d /var/lib/orchestrator/shared/skills/verified 0755 root root -"
    "d /var/lib/orchestrator/shared/escalation-log 0755 root root -"
    "d /var/lib/orchestrator/shared/escalation-log/coding 0755 root root -"
    "d /var/lib/orchestrator/shared/escalation-log/review 0755 root root -"
    "d /var/lib/orchestrator/shared/escalation-log/writing 0755 root root -"
    "d /var/lib/orchestrator/shared/escalation-log/research 0755 root root -"
    # Trajectory capture for RL training
    "d /var/lib/orchestrator/shared/trajectories 0755 root root -"
    "d /var/lib/orchestrator/shared/trajectories/scored 0755 root root -"
    # Workflow storage
    "d /var/lib/orchestrator/workflows 0755 root root -"
  ];

  # Seed Wanda's identity + MCP scripts (only if not already present — preserves growth)
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
      mkdir -p /var/lib/orchestrator/shared/{skills/verified,escalation-log/{coding,review,writing,research}}
      mkdir -p /var/lib/orchestrator/shared/trajectories/scored
      mkdir -p /var/lib/orchestrator/mcp-servers

      # Syncthing folder marker (required for sync to work)
      touch /var/lib/orchestrator/shared/.stfolder

      # Syncthing runs as jon — ensure it can read/write the shared dir
      chown -R jon:users /var/lib/orchestrator/shared

      mkdir -p /var/lib/orchestrator/workflows
      mkdir -p /var/lib/hermes/lib

      seed_file() {
        local dest="$1"
        local src="$2"
        if [ ! -f "$dest" ]; then
          cp "$src" "$dest"
          echo "Seeded $dest"
        fi
      }

      # Wanda — the Brain
      seed_file /var/lib/orchestrator/wanda/IDENTITY.md ${wanda-identity}
      seed_file /var/lib/orchestrator/wanda/SOUL.md ${wanda-soul}
      seed_file /var/lib/orchestrator/wanda/USER.md ${wanda-user}
      seed_file /var/lib/orchestrator/wanda/personality.yaml ${wanda-personality}

      # Anti-loop system prompt
      cp ${builtins.path { path = ../../agents/SYSTEM.md; name = "agent-SYSTEM.md"; }} /var/lib/orchestrator/wanda/SYSTEM.md

      # Wanda's memory starts empty — she fills it via RL
      if [ ! -f /var/lib/orchestrator/wanda/MEMORY.md ]; then
        cat > /var/lib/orchestrator/wanda/MEMORY.md << 'SEED'
# MEMORY.md — Wanda

*This file is mine. I update it as I learn.*

## Routing Patterns

## Lessons

## Training Observations
SEED
        echo "Seeded /var/lib/orchestrator/wanda/MEMORY.md"
      fi

      # MCP server scripts — always overwritten (nix-managed)
      cp ${mcpDispatch} /var/lib/orchestrator/mcp-servers/dispatch.py
      cp ${mcpEscalation} /var/lib/orchestrator/mcp-servers/escalation.py
      cp ${mcpMemory} /var/lib/orchestrator/mcp-servers/memory.py
      cp ${mcpClawhub} /var/lib/orchestrator/mcp-servers/clawhub.py

      # Hermes entrypoint + ACP adapter
      cp ${hermesEntrypoint} /var/lib/hermes/entrypoint.sh
      cp ${hermesAdapter} /var/lib/hermes/hermes-acp-adapter.py

      # Lobster workflow files
      seed_file /var/lib/orchestrator/workflows/dispatch.yaml ${wf-dispatch}
      seed_file /var/lib/orchestrator/workflows/escalation.yaml ${wf-escalation}
      seed_file /var/lib/orchestrator/workflows/content-task.yaml ${wf-content}
      seed_file /var/lib/orchestrator/workflows/research-task.yaml ${wf-research}
      seed_file /var/lib/orchestrator/workflows/wp-task.yaml ${wf-wp}
    '';
  };

  # Hermes Agent — Wanda runs inside an OpenSandbox container (air-gapped)
  # Network: filesystem queue writes + SGLang inference + frontier APIs
  # NO opensandbox API access — agent-runner handles sandbox spawning
  systemd.services.orchestrator = {
    description = "Wanda — Hermes Brain (NAS, air-gapped)";
    after = [ "opensandbox-server.service" "opensandbox-pull-images.service" "network-online.target" ];
    requires = [ "opensandbox-server.service" ];
    wants = [ "network-online.target" "opensandbox-pull-images.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      RestartSec = 10;
      ExecStartPre = "${pkgs.writeShellScript "orchestrator-pre-cleanup" ''
        # Remove stale orchestrator sandbox from previous run
        SANDBOX_ID=$(cat /var/lib/orchestrator/wanda-sandbox-id 2>/dev/null || true)
        if [ -n "$SANDBOX_ID" ]; then
          ${pkgs.curl}/bin/curl -sf -X DELETE "http://localhost:8080/v1/sandboxes/$SANDBOX_ID" 2>/dev/null || true
          rm -f /var/lib/orchestrator/wanda-sandbox-id
        fi
      ''}";
      ExecStopPost = "${pkgs.writeShellScript "orchestrator-cleanup" ''
        # Clean up sandbox
        SANDBOX_ID=$(cat /var/lib/orchestrator/wanda-sandbox-id 2>/dev/null || true)
        if [ -n "$SANDBOX_ID" ]; then
          ${pkgs.curl}/bin/curl -sf -X DELETE "http://localhost:8080/v1/sandboxes/$SANDBOX_ID" 2>/dev/null || true
          rm -f /var/lib/orchestrator/wanda-sandbox-id
        fi
      ''}";
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

      # Load secrets from agenix
      source ${config.age.secrets.openrouter-api-key.path}

      # Create orchestrator sandbox via OpenSandbox API
      # Image: acp-reasoning (has Python 3.12, pip, bash, jq, curl)
      # Network: deny-by-default, allow only SGLang + evaluator + frontier
      # Volumes: identity, queue, workflows, MCP scripts, hermes runtime
      SANDBOX_ID=$(curl -sf -X POST http://localhost:8080/v1/sandboxes \
        -H 'Content-Type: application/json' \
        -d '{
          "image": {"uri": "acp-reasoning:latest"},
          "timeout": 86400,
          "resourceLimits": {"cpu": "1000m", "memory": "2Gi"},
          "entrypoint": ["bash", "/workspace/hermes/entrypoint.sh"],
          "env": {
            "OPENAI_BASE_URL": "http://172.17.0.1:11434/v1",
            "OPENAI_API_KEY": "ollama",
            "LLM_MODEL": "openai/Qwen/Qwen3.5-9B",
            "OPENROUTER_API_KEY": "'"$OPENROUTER_API_KEY"'",
            "EVALUATOR_URL": "http://172.17.0.1:11435/v1",
            "EVALUATOR_MODEL": "Qwen/Qwen3.5-35B-A3B",
            "EVALUATOR_API_KEY": "ollama",
            "QUEUE_BASE": "/workspace/shared/queue",
            "ESCALATION_LOG_DIR": "/workspace/shared/escalation-log",
            "AGENTS_DIR": "/workspace/agents",
            "WANDA_DIR": "/workspace/wanda",
            "VERIFIED_DIR": "/workspace/shared/skills/verified",
            "TRAJECTORY_DIR": "/workspace/shared/trajectories",
            "HOME": "/workspace/hermes",
            "PYTHONPATH": "/workspace/hermes/lib",
            "PATH": "/workspace/hermes/lib/bin:/home/agent/.local/bin:/usr/bin:/bin"
          },
          "networkPolicy": ${networkPolicy},
          "volumes": [
            {"name": "wanda-identity", "host": {"path": "/var/lib/orchestrator/wanda"}, "mountPath": "/workspace/wanda"},
            {"name": "shared-queue", "host": {"path": "/var/lib/orchestrator/shared"}, "mountPath": "/workspace/shared"},
            {"name": "workflows", "host": {"path": "/var/lib/orchestrator/workflows"}, "mountPath": "/workspace/workflows"},
            {"name": "mcp-servers", "host": {"path": "/var/lib/orchestrator/mcp-servers"}, "mountPath": "/opt/mcp-servers"},
            {"name": "hermes-runtime", "host": {"path": "/var/lib/hermes"}, "mountPath": "/workspace/hermes"}
          ]
        }' | jq -r '.id')

      if [ -z "$SANDBOX_ID" ] || [ "$SANDBOX_ID" = "null" ]; then
        echo "Failed to create orchestrator sandbox"
        exit 1
      fi

      echo "Wanda is awake (sandbox: $SANDBOX_ID, air-gapped)"
      echo "$SANDBOX_ID" > /var/lib/orchestrator/wanda-sandbox-id

      # Wait for sandbox to become Running
      echo "Waiting for Wanda to become healthy..."
      for i in $(seq 1 60); do
        STATUS=$(curl -sf "http://localhost:8080/v1/sandboxes/$SANDBOX_ID" | jq -r '.status.state' 2>/dev/null)
        if [ "$STATUS" = "Running" ]; then
          echo "Wanda is healthy (attempt $i)"
          break
        fi
        if [ "$STATUS" = "Failed" ] || [ "$STATUS" = "Terminated" ]; then
          echo "Wanda failed to start (status: $STATUS)"
          exit 1
        fi
        sleep 5
      done

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

  # Firewall — OpenSandbox API on Tailscale
  networking.firewall.allowedTCPPorts = [ 8080 ];
}
