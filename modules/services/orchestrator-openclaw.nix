{ pkgs, config, lib, ... }:

let
  hostname = config.networking.hostName;
  isNas = hostname == "nas";

  # Network policy: filesystem (queue writes) + localhost vLLM + frontier APIs
  networkPolicy = builtins.toJSON {
    defaultAction = "deny";
    egress = [
      { action = "allow"; target = "172.17.0.1:11434"; }
      { action = "allow"; target = "172.17.0.1:11435"; }
      { action = "allow"; target = "openrouter.ai:443"; }
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
      wanda-identity = builtins.path { path = ../../agents/wanda/IDENTITY.md; name = "wanda-IDENTITY.md"; };
      wanda-soul = builtins.path { path = ../../agents/wanda/SOUL.md; name = "wanda-SOUL.md"; };
      wanda-user = builtins.path { path = ../../agents/wanda/USER.md; name = "wanda-USER.md"; };
      wanda-personality = builtins.path { path = ../../agents/wanda/personality.yaml; name = "wanda-personality.yaml"; };
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

      # Anti-loop system prompt — prevents 4-bit reasoning spirals
      cp ${builtins.path { path = ../../agents/SYSTEM.md; name = "agent-SYSTEM.md"; }} /var/lib/orchestrator/wanda/SYSTEM.md

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

      # OpenClaw gateway config — vLLM as default provider, Anthropic as escalation
      mkdir -p /var/lib/orchestrator/wanda-config
      if [ -f ${config.age.secrets.openrouter-api-key.path} ]; then
        source ${config.age.secrets.openrouter-api-key.path}
        export OPENROUTER_API_KEY
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
    "OPENROUTER_API_KEY": "$OPENROUTER_API_KEY"
  },
  "models": {
    "providers": {
      "vllm": {
        "baseUrl": "http://172.17.0.1:11434/v1",
        "apiKey": "ollama",
        "api": "openai-completions",
        "models": [
          {
            "id": "Qwen/Qwen3.5-9B",
            "name": "Qwen 3.5 9B (NAS, vLLM ROCm, 32K ctx)",
            "contextWindow": 32768
          }
        ]
      },
      "vllm-light": {
        "baseUrl": "http://172.17.0.1:11435/v1",
        "apiKey": "ollama",
        "api": "openai-completions",
        "models": [
          {
            "id": "Qwen/Qwen3.5-0.8B",
            "name": "Qwen 3.5 0.8B (NAS, vLLM CPU, 16K ctx)",
            "contextWindow": 16384
          }
        ]
      },
      "openrouter": {
        "baseUrl": "https://openrouter.ai/api/v1",
        "apiKey": "$OPENROUTER_API_KEY",
        "api": "openai-completions",
        "models": [
          {
            "id": "qwen/qwen3.5-397b-a17b",
            "name": "Qwen 3.5 397B-A17B MoE (OpenRouter, 262K ctx)",
            "contextWindow": 262144
          },
          {
            "id": "anthropic/claude-opus-4-6",
            "name": "Claude Opus 4.6 (OpenRouter, break-glass)",
            "contextWindow": 200000
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "vllm/Qwen/Qwen3.5-9B"
      },
      "runtime": "acp",
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
        "id": "cosmo",
        "runtime": "acp",
        "role": "lead",
        "workspace": "/home/node/.openclaw/agents-workspace/cosmo",
        "tools": {
          "allow": ["read", "write", "lobster", "adk", "clawhub", "agent-delegate"]
        },
        "description": "Technical lead. Designs Lobster workflows, delegates to agents, reviews results."
      },
      {
        "id": "coder",
        "runtime": "acp",
        "workspace": "/home/node/.openclaw/agents-workspace/coder",
        "tools": {
          "allow": ["read", "write", "edit", "shell", "git"]
        }
      },
      {
        "id": "reviewer",
        "runtime": "acp",
        "workspace": "/home/node/.openclaw/agents-workspace/reviewer",
        "tools": {
          "allow": ["read", "shell"]
        }
      },
      {
        "id": "deployer",
        "runtime": "acp",
        "workspace": "/home/node/.openclaw/agents-workspace/deployer",
        "tools": {
          "allow": ["read", "shell", "git"]
        }
      },
      {
        "id": "writer",
        "runtime": "acp",
        "workspace": "/home/node/.openclaw/agents-workspace/writer",
        "tools": {
          "allow": ["read", "write", "edit"]
        }
      },
      {
        "id": "reader",
        "runtime": "acp",
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
      "allow": ["cosmo", "coder", "reviewer", "deployer", "writer", "reader"]
    },
    "sessions": {
      "visibility": "all"
    }
  }
}
OCCONFIG

      # OpenClaw agent auth — OpenRouter for all external models (Qwen 397B, Opus)
      mkdir -p /var/lib/orchestrator/wanda-config/agents/main/agent
      if [ -n "$OPENROUTER_API_KEY" ]; then
        cat > /var/lib/orchestrator/wanda-config/agents/main/agent/auth-profiles.json << AUTHEOF
{
  "version": 1,
  "profiles": {
    "openrouter:default": {
      "type": "token",
      "provider": "openrouter",
      "token": "$OPENROUTER_API_KEY"
    }
  },
  "order": {
    "openrouter": ["openrouter:default"]
  },
  "lastGood": {
    "openrouter": "openrouter:default"
  }
}
AUTHEOF
      fi

      # Seed sub-agent workspaces (all agents known to Wanda's Carapace)
      mkdir -p /var/lib/orchestrator/wanda-config/agents-workspace/{cosmo,coder,reviewer,deployer,writer,reader}

      # Cosmo — technical lead (workstation)
      seed_file /var/lib/orchestrator/wanda-config/agents-workspace/cosmo/IDENTITY.md ${builtins.path { path = ../../cosmo/IDENTITY.md; name = "cosmo-IDENTITY.md"; }}
      seed_file /var/lib/orchestrator/wanda-config/agents-workspace/cosmo/SOUL.md ${builtins.path { path = ../../cosmo/SOUL.md; name = "cosmo-SOUL.md"; }}
      cp ${wanda-user} /var/lib/orchestrator/wanda-config/agents-workspace/cosmo/USER.md

      # Coder (workstation)
      seed_file /var/lib/orchestrator/wanda-config/agents-workspace/coder/SOUL.md ${builtins.path { path = ../../agents/coder/SOUL.md; name = "coder-SOUL.md"; }}
      seed_file /var/lib/orchestrator/wanda-config/agents-workspace/coder/AGENTS.md ${builtins.path { path = ../../agents/coder/AGENTS.md; name = "coder-AGENTS.md"; }}
      cp ${wanda-user} /var/lib/orchestrator/wanda-config/agents-workspace/coder/USER.md

      # Reviewer (workstation)
      seed_file /var/lib/orchestrator/wanda-config/agents-workspace/reviewer/SOUL.md ${builtins.path { path = ../../agents/reviewer/SOUL.md; name = "reviewer-SOUL.md"; }}
      seed_file /var/lib/orchestrator/wanda-config/agents-workspace/reviewer/AGENTS.md ${builtins.path { path = ../../agents/reviewer/AGENTS.md; name = "reviewer-AGENTS.md"; }}
      cp ${wanda-user} /var/lib/orchestrator/wanda-config/agents-workspace/reviewer/USER.md

      # Deployer (workstation)
      seed_file /var/lib/orchestrator/wanda-config/agents-workspace/deployer/SOUL.md ${builtins.path { path = ../../agents/deployer/SOUL.md; name = "deployer-SOUL.md"; }}
      seed_file /var/lib/orchestrator/wanda-config/agents-workspace/deployer/AGENTS.md ${builtins.path { path = ../../agents/deployer/AGENTS.md; name = "deployer-AGENTS.md"; }}
      cp ${wanda-user} /var/lib/orchestrator/wanda-config/agents-workspace/deployer/USER.md

      # Writer (NAS)
      seed_file /var/lib/orchestrator/wanda-config/agents-workspace/writer/SOUL.md ${builtins.path { path = ../../agents/writer/SOUL.md; name = "writer-SOUL.md"; }}
      seed_file /var/lib/orchestrator/wanda-config/agents-workspace/writer/AGENTS.md ${builtins.path { path = ../../agents/writer/AGENTS.md; name = "writer-AGENTS.md"; }}
      cp ${wanda-user} /var/lib/orchestrator/wanda-config/agents-workspace/writer/USER.md

      # Reader (NAS)
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

  # OpenClaw orchestrator — Wanda runs as a Python coordinator (ROCK SDK)
  # Network: filesystem queue writes + localhost vLLM + openrouter.ai
  systemd.services.orchestrator = {
    description = "Wanda — OpenClaw Orchestrator (NAS)";
    after = [ "network-online.target" "caddy.service" ];
    wants = [ "network-online.target" "caddy.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      RestartSec = 10;
      ExecStartPre = "${pkgs.writeShellScript "orchestrator-pre-cleanup" ''
        rm -f /var/lib/orchestrator/wanda-sandbox-id /var/lib/orchestrator/wanda-proxy-port
      ''}";
      ExecStopPost = "${pkgs.writeShellScript "orchestrator-cleanup" ''
        rm -f /var/lib/orchestrator/wanda-sandbox-id /var/lib/orchestrator/wanda-proxy-port
        rm -f /var/www/html/wanda/caddyfile
        /run/current-system/sw/bin/systemctl reload caddy 2>/dev/null || true
        ${pkgs.tailscale}/bin/tailscale serve --https=8100 off 2>/dev/null || true
      ''}";
    };
    path = [ pkgs.curl pkgs.jq pkgs.tailscale pkgs.gh pkgs.git pkgs.openclaw.openclaw-run ];
    script = ''
      # Load secrets from agenix
      source ${config.age.secrets.openrouter-api-key.path}
      source ${config.age.secrets.gateway-token.path}

      echo "Starting OpenClaw coordinator (Wanda)..."

      # Run the Python coordinator — it manages ROCK sandboxes and GH issues
      exec openclaw-run
    '';
  };
}
