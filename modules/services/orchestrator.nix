{ pkgs, config, lib, ... }:

let
  hostname = config.networking.hostName;
  isNas = hostname == "nas";

  opensandbox-server = pkgs.callPackage ../../pkgs/opensandbox-server {};

  # Network policy: filesystem (queue writes) + localhost ollama + Anthropic API
  # NO opensandbox API access — Wanda never spawns sandboxes directly
  networkPolicy = builtins.toJSON {
    defaultAction = "deny";
    egress = [
      { action = "allow"; target = "172.17.0.1:11434"; }
      { action = "allow"; target = "api.anthropic.com:443"; }
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

      # Syncthing folder marker (required for sync to work)
      touch /var/lib/orchestrator/shared/.stfolder

      # Syncthing runs as jon — ensure it can read/write the shared dir
      chown -R jon:users /var/lib/orchestrator/shared
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

      # OpenClaw reads identity from workspace/ — copy Wanda's files there
      mkdir -p /var/lib/orchestrator/wanda-config/workspace
      cp ${wanda-identity} /var/lib/orchestrator/wanda-config/workspace/IDENTITY.md
      cp ${wanda-soul} /var/lib/orchestrator/wanda-config/workspace/SOUL.md
      cp ${wanda-user} /var/lib/orchestrator/wanda-config/workspace/USER.md

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

      # OpenClaw gateway config — ollama as default provider, Anthropic as escalation
      mkdir -p /var/lib/orchestrator/wanda-config
      if [ -f ${config.age.secrets.anthropic-api-key.path} ]; then
        source ${config.age.secrets.anthropic-api-key.path}
        export ANTHROPIC_API_KEY
      fi
      cat > /var/lib/orchestrator/wanda-config/openclaw.json << OCCONFIG
{
  "gateway": {
    "auth": {
      "allowTailscale": true
    },
    "controlUi": {
      "dangerouslyAllowHostHeaderOriginFallback": true
    },
    "trustedProxies": ["127.0.0.1", "172.17.0.0/16"]
  },
  "plugins": {
    "entries": {
      "lobster": {
        "enabled": true
      }
    }
  },
  "env": {
    "ANTHROPIC_API_KEY": "$ANTHROPIC_API_KEY"
  },
  "models": {
    "providers": {
      "ollama": {
        "baseUrl": "http://172.17.0.1:11434/v1",
        "apiKey": "ollama-local",
        "api": "openai-completions",
        "models": [
          {
            "id": "gemma3:12b",
            "name": "Gemma 3 12B",
            "contextWindow": 65536
          },
          {
            "id": "qwen3:8b",
            "name": "Qwen 3 8B",
            "contextWindow": 32768
          },
          {
            "id": "qwen3:14b",
            "name": "Qwen 3 14B",
            "contextWindow": 32768
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "ollama/qwen3:14b"
      },
      "subagents": {
        "maxSpawnDepth": 2,
        "maxChildrenPerAgent": 5,
        "maxConcurrent": 3,
        "runTimeoutSeconds": 900
      }
    },
    "list": [
      {
        "id": "main",
        "workspace": "/home/node/.openclaw/workspace",
        "tools": {
          "alsoAllow": ["lobster", "sessions_spawn", "sessions_send", "sessions_list", "sessions_history"]
        },
        "subagents": {
          "allowAgents": ["*"]
        }
      },
      {
        "id": "writer",
        "workspace": "/home/node/.openclaw/agents-workspace/writer",
        "tools": {
          "allow": ["read", "write", "edit"]
        }
      },
      {
        "id": "reader",
        "workspace": "/home/node/.openclaw/agents-workspace/reader",
        "tools": {
          "allow": ["read"]
        }
      }
    ]
  },
  "tools": {
    "agentToAgent": {
      "enabled": true,
      "allow": ["writer", "reader"]
    }
  }
}
OCCONFIG

      # OpenClaw agent auth — seed auth-profiles.json as backup
      mkdir -p /var/lib/orchestrator/wanda-config/agents/main/agent
      if [ -n "$ANTHROPIC_API_KEY" ]; then
        cat > /var/lib/orchestrator/wanda-config/agents/main/agent/auth-profiles.json << AUTHEOF
{
  "version": 1,
  "profiles": {
    "anthropic:default": {
      "type": "token",
      "provider": "anthropic",
      "token": "$ANTHROPIC_API_KEY"
    }
  },
  "order": {
    "anthropic": ["anthropic:default"]
  },
  "lastGood": {
    "anthropic": "anthropic:default"
  }
}
AUTHEOF
      fi

      # Seed sub-agent workspaces
      mkdir -p /var/lib/orchestrator/wanda-config/agents-workspace/writer
      mkdir -p /var/lib/orchestrator/wanda-config/agents-workspace/reader
      seed_file /var/lib/orchestrator/wanda-config/agents-workspace/writer/SOUL.md ${builtins.path { path = ../../agents/writer/SOUL.md; name = "writer-SOUL.md"; }}
      seed_file /var/lib/orchestrator/wanda-config/agents-workspace/writer/AGENTS.md ${builtins.path { path = ../../agents/writer/AGENTS.md; name = "writer-AGENTS.md"; }}
      cp ${wanda-user} /var/lib/orchestrator/wanda-config/agents-workspace/writer/USER.md
      seed_file /var/lib/orchestrator/wanda-config/agents-workspace/reader/SOUL.md ${builtins.path { path = ../../agents/reader/SOUL.md; name = "reader-SOUL.md"; }}
      seed_file /var/lib/orchestrator/wanda-config/agents-workspace/reader/AGENTS.md ${builtins.path { path = ../../agents/reader/AGENTS.md; name = "reader-AGENTS.md"; }}
      cp ${wanda-user} /var/lib/orchestrator/wanda-config/agents-workspace/reader/USER.md

      # Fix permissions — container runs as node (UID 1000)
      chown -R 1000:1000 /var/lib/orchestrator/wanda
      chown -R 1000:1000 /var/lib/orchestrator/wanda-config

      # Lobster workflow files
      seed_file /var/lib/orchestrator/workflows/dispatch.yaml ${wf-dispatch}
      seed_file /var/lib/orchestrator/workflows/escalation.yaml ${wf-escalation}
      seed_file /var/lib/orchestrator/workflows/content-task.yaml ${wf-content}
      seed_file /var/lib/orchestrator/workflows/research-task.yaml ${wf-research}
      seed_file /var/lib/orchestrator/workflows/wp-task.yaml ${wf-wp}
    '';
  };

  # OpenClaw orchestrator — Wanda runs inside an OpenSandbox container
  # Network: filesystem queue writes + localhost:11434 (ollama) + api.anthropic.com:443
  # NO opensandbox API access — agent-runner handles sandbox spawning
  systemd.services.orchestrator = {
    description = "Wanda — OpenClaw Orchestrator (NAS, air-gapped)";
    after = [ "opensandbox-server.service" "opensandbox-pull-images.service" "network-online.target" "caddy.service" ];
    requires = [ "opensandbox-server.service" ];
    wants = [ "network-online.target" "opensandbox-pull-images.service" "caddy.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      RestartSec = 10;
      ExecStopPost = "${pkgs.writeShellScript "orchestrator-cleanup" ''
        rm -f /var/www/html/wanda/caddyfile
        /run/current-system/sw/bin/systemctl reload caddy 2>/dev/null || true
        ${pkgs.tailscale}/bin/tailscale serve --https=8100 off 2>/dev/null || true
      ''}";
    };
    path = [ pkgs.curl pkgs.jq pkgs.tailscale ];
    script = ''
      # Wait for OpenSandbox API to be ready
      for i in $(seq 1 30); do
        if curl -sf http://localhost:8080/health > /dev/null 2>&1; then
          break
        fi
        sleep 2
      done

      # Load Anthropic API key from agenix secret
      source ${config.age.secrets.anthropic-api-key.path}

      # Create orchestrator sandbox via OpenSandbox API
      # Follows the official OpenSandbox + OpenClaw example pattern
      # Network: queue dir (filesystem) + localhost ollama + api.anthropic.com
      SANDBOX_ID=$(curl -sf -X POST http://localhost:8080/v1/sandboxes \
        -H 'Content-Type: application/json' \
        -d '{
          "image": {"uri": "ghcr.io/openclaw/openclaw:latest"},
          "timeout": 86400,
          "resourceLimits": {"cpu": "1000m", "memory": "2Gi"},
          "entrypoint": ["node", "dist/index.js", "gateway", "--bind=lan", "--port=8100", "--allow-unconfigured", "--verbose"],
          "env": {"OPENCLAW_GATEWAY_TOKEN": "wanda-fleet-token", "ANTHROPIC_API_KEY": "'"$ANTHROPIC_API_KEY"'", "NODE_PATH": "/opt/lobster/node_modules", "PATH": "/opt/lobster/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"},
          "networkPolicy": ${networkPolicy},
          "volumes": [
            {"name": "wanda-config", "host": {"path": "/var/lib/orchestrator/wanda-config"}, "mountPath": "/home/node/.openclaw"},
            {"name": "wanda-identity", "host": {"path": "/var/lib/orchestrator/wanda"}, "mountPath": "/home/node/.openclaw/identity"},
            {"name": "shared-queue", "host": {"path": "/var/lib/orchestrator/shared"}, "mountPath": "/home/node/.openclaw/shared"},
            {"name": "workflows", "host": {"path": "/var/lib/orchestrator/workflows"}, "mountPath": "/home/node/.openclaw/workflows"},
            {"name": "lobster", "host": {"path": "/var/lib/orchestrator/lobster"}, "mountPath": "/opt/lobster"},
            {"name": "agents-workspace", "host": {"path": "/var/lib/orchestrator/wanda-config/agents-workspace"}, "mountPath": "/home/node/.openclaw/agents-workspace"}
          ]
        }' | jq -r '.id')

      if [ -z "$SANDBOX_ID" ] || [ "$SANDBOX_ID" = "null" ]; then
        echo "Failed to create orchestrator sandbox"
        exit 1
      fi

      echo "Wanda is awake (sandbox: $SANDBOX_ID)"

      # Write sandbox ID for easy access from other hosts
      echo "$SANDBOX_ID" > /var/lib/orchestrator/wanda-sandbox-id

      # Discover the dynamic proxy port for the gateway
      ENDPOINT=$(curl -sf "http://localhost:8080/v1/sandboxes/$SANDBOX_ID/endpoints/8100" | jq -r '.endpoint')
      PROXY_PORT=$(echo "$ENDPOINT" | grep -oP ':\K[0-9]+')
      echo "$PROXY_PORT" > /var/lib/orchestrator/wanda-proxy-port
      echo "Wanda gateway: opensandbox proxy port $PROXY_PORT"

      # Write caddyfile for system Caddy (Cloudflare TLS via caddy.nix)
      # Caddy natively handles WebSocket upgrade — no extra config needed
      # HTTPS required: OpenClaw Control UI needs secure context for device identity
      if [ -n "$PROXY_PORT" ]; then
        mkdir -p /var/www/html/wanda
        # Base64-encode caddyfile to preserve '#' (Caddyfile comment char)
        echo "d2FuZGEuaGVsbGZpcmVhZS5jb20gewogIGltcG9ydCBjbG91ZGZsYXJlLXRscwogIGJpbmQgMTAwLjk1LjIwMS4xMAoKICBAbG9naW4gcGF0aCAvbG9naW4KICByZWRpciBAbG9naW4gIi8jdG9rZW49d2FuZGEtZmxlZXQtdG9rZW4iCgogIHJld3JpdGUgKiAvcHJveHkvODEwMHt1cml9CiAgcmV2ZXJzZV9wcm94eSAxMjcuMC4wLjE6UFJPWFlfUE9SVCB7CiAgICBoZWFkZXJfdXAgWC1Gb3J3YXJkZWQtUHJvdG8gaHR0cHMKICB9Cn0K" \
          | base64 -d \
          | sed "s/PROXY_PORT/$PROXY_PORT/" \
          > /var/www/html/wanda/caddyfile
        /run/current-system/sw/bin/systemctl reload caddy
        echo "Caddy: https://wanda.hellfireae.com → :$PROXY_PORT/proxy/8100/"

        # Tailscale serve — tailnet-authenticated HTTPS on :8100
        tailscale serve --bg --https 8100 "http://127.0.0.1:$PROXY_PORT/proxy/8100/"
        echo "Tailscale: https://wanda.starling-ostrich.ts.net:8100 → :$PROXY_PORT/proxy/8100/"
      fi

      # Wait for sandbox to become Running (gateway takes a few seconds to start)
      echo "Waiting for Wanda to become healthy..."
      for i in $(seq 1 30); do
        STATUS=$(curl -sf "http://localhost:8080/v1/sandboxes/$SANDBOX_ID" | jq -r '.status.state' 2>/dev/null)
        if [ "$STATUS" = "Running" ]; then
          echo "Wanda is healthy (attempt $i)"
          break
        fi
        if [ "$STATUS" = "Failed" ] || [ "$STATUS" = "Terminated" ]; then
          echo "Wanda failed to start (status: $STATUS)"
          exit 1
        fi
        sleep 2
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

  # Firewall — opensandbox API on Tailscale (gateway via system Caddy on 443)
  networking.firewall.allowedTCPPorts = [ 8080 ];
}
