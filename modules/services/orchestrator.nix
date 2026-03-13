# Hermes Agent — Brain tier orchestrator (NAS only)
# Replaces OpenClaw with Hermes as native systemd service.
# Hermes handles routing, delegation, MCP tools, and trajectory capture.
# Identity: Wanda (IDENTITY.md, SOUL.md, USER.md, MEMORY.md)
#
# Rollback: swap import to orchestrator-openclaw.nix in flake.nix
{ pkgs, config, lib, ... }:

let
  hostname = config.networking.hostName;
  isNas = hostname == "nas";

  pythonEnv = pkgs.python312.withPackages (ps: with ps; [
    pip
    setuptools
    requests
    pyyaml
  ]);

  # Hermes config pointing to local SGLang
  hermesConfig = pkgs.writeText "hermes-config.yaml" ''
    model:
      default: "openai/Qwen/Qwen3.5-9B"
      provider: "auto"

    terminal:
      backend: "local"
      cwd: "/var/lib/orchestrator/shared"
      timeout: 300

    mcp_servers:
      dispatch:
        command: "${pythonEnv}/bin/python"
        args: ["${../../pkgs/mcp-servers/dispatch.py}"]
        env:
          QUEUE_BASE: "/var/lib/orchestrator/shared/queue"
      escalation:
        command: "${pythonEnv}/bin/python"
        args: ["${../../pkgs/mcp-servers/escalation.py}"]
        env:
          EVALUATOR_URL: "http://localhost:11435/v1"
          EVALUATOR_MODEL: "Qwen/Qwen3.5-35B-A3B"
          ESCALATION_LOG_DIR: "/var/lib/orchestrator/shared/escalation-log"
      memory:
        command: "${pythonEnv}/bin/python"
        args: ["${../../pkgs/mcp-servers/memory.py}"]
        env:
          AGENTS_DIR: "/var/lib/orchestrator/agents"
          WANDA_DIR: "/var/lib/orchestrator/wanda"
  '';

  hermesEnvFile = pkgs.writeText "hermes-env" ''
    OPENAI_BASE_URL=http://localhost:11434/v1
    OPENAI_API_KEY=ollama
    LLM_MODEL=openai/Qwen/Qwen3.5-9B
  '';
in
lib.mkIf isNas {
  # Orchestrator directory structure (persists across nixos-rebuild)
  systemd.tmpfiles.rules = [
    "d /var/lib/orchestrator 0755 root root -"
    # Wanda — the Brain's identity and memory
    "d /var/lib/orchestrator/wanda 0755 root root -"
    "d /var/lib/orchestrator/wanda/memory 0755 root root -"
    # Hermes runtime
    "d /var/lib/hermes 0755 root root -"
    "d /var/lib/hermes/lib 0755 root root -"
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

  # Seed Wanda's identity (only if not already present — preserves growth)
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

      # Hermes config
      mkdir -p /var/lib/hermes
      cp ${hermesConfig} /var/lib/hermes/config.yaml
      cp ${hermesEnvFile} /var/lib/hermes/.env

      # Lobster workflow files
      seed_file /var/lib/orchestrator/workflows/dispatch.yaml ${wf-dispatch}
      seed_file /var/lib/orchestrator/workflows/escalation.yaml ${wf-escalation}
      seed_file /var/lib/orchestrator/workflows/content-task.yaml ${wf-content}
      seed_file /var/lib/orchestrator/workflows/research-task.yaml ${wf-research}
      seed_file /var/lib/orchestrator/workflows/wp-task.yaml ${wf-wp}
    '';
  };

  # Hermes Agent — Brain orchestrator as native systemd service
  # Routes tasks to Engineer (Qwen-Agent) or Grunt (NullClaw) via MCP dispatch
  # Scores trajectories via MoE evaluator (35B-A3B) via MCP escalation
  # Captures routing decisions in MEMORY.md via MCP memory
  systemd.services.orchestrator = {
    description = "Hermes Agent — Brain (NAS)";
    after = [ "docker-sglang.service" "opensandbox-server.service" "network-online.target" ];
    wants = [ "network-online.target" "docker-sglang.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      RestartSec = 10;
      TimeoutStartSec = 300;
    };
    path = [ pythonEnv pkgs.curl pkgs.jq pkgs.git ];
    environment = {
      OPENAI_BASE_URL = "http://localhost:11434/v1";
      OPENAI_API_KEY = "ollama";
      LLM_MODEL = "openai/Qwen/Qwen3.5-9B";
      HERMES_HOME = "/var/lib/hermes";
      PYTHONPATH = "/var/lib/hermes/lib";
      HOME = "/var/lib/hermes";
      QUEUE_BASE = "/var/lib/orchestrator/shared/queue";
      EVALUATOR_URL = "http://localhost:11435/v1";
      EVALUATOR_MODEL = "Qwen/Qwen3.5-35B-A3B";
    };
    script = ''
      # Wait for SGLang to be ready
      for i in $(seq 1 60); do
        if curl -sf -H "Authorization: Bearer ollama" http://localhost:11434/v1/models > /dev/null 2>&1; then
          echo "SGLang is ready"
          break
        fi
        sleep 5
      done

      # Install hermes-agent if not already present
      if [ ! -f /var/lib/hermes/.installed ]; then
        echo "Installing hermes-agent..."
        ${pythonEnv}/bin/pip install --target /var/lib/hermes/lib \
          "hermes-agent[mcp]" 2>&1 | tail -5
        touch /var/lib/hermes/.installed
      fi

      # Load secrets for frontier escalation
      if [ -f ${config.age.secrets.openrouter-api-key.path} ]; then
        source ${config.age.secrets.openrouter-api-key.path}
        export OPENROUTER_API_KEY
      fi

      echo "Wanda is awake (Hermes Brain)"

      # Main loop: watch queue for tasks, process via Hermes
      QUEUE_DIR="/var/lib/orchestrator/shared/queue/nas"
      RESULTS_DIR="/var/lib/orchestrator/shared/queue/results"

      process_task() {
        local task_file="$1"
        local task_id=$(basename "$task_file" .json)
        local prompt=$(${pkgs.jq}/bin/jq -r '.prompt // ""' "$task_file")

        echo "Processing task $task_id via Hermes"

        local result_dir="$RESULTS_DIR/$task_id"
        mkdir -p "$result_dir"

        # Run through Hermes ACP adapter
        echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' | \
          TASK_FILE="$task_file" ${pythonEnv}/bin/python ${../../pkgs/hermes-agent/hermes-acp-adapter.py} > /dev/null 2>&1 || true

        # Simple direct call for now — Hermes chat() handles routing internally
        ${pythonEnv}/bin/python -c "
import sys, json, os
sys.path.insert(0, '/var/lib/hermes/lib')
try:
    from run_agent import AIAgent
    agent = AIAgent(
        model=os.environ.get('LLM_MODEL', 'openai/Qwen/Qwen3.5-9B'),
        base_url=os.environ.get('OPENAI_BASE_URL', 'http://localhost:11434/v1'),
        api_key=os.environ.get('OPENAI_API_KEY', 'ollama'),
        max_iterations=50,
        quiet_mode=True,
        save_trajectories=True,
    )
    result = agent.chat('''$prompt''')
    with open('$result_dir/output.txt', 'w') as f:
        f.write(result or 'No output')
    print(f'Task $task_id completed')
except Exception as e:
    with open('$result_dir/error.txt', 'w') as f:
        f.write(str(e))
    print(f'Task $task_id failed: {e}')
" 2>&1

        mv "$task_file" "$RESULTS_DIR/$task_id.done.json"
        echo "Task $task_id done (results in $result_dir)"
      }

      # Poll queue
      while true; do
        for task_file in "$QUEUE_DIR"/*.json; do
          [ -f "$task_file" ] || continue
          process_task "$task_file"
        done
        ${pkgs.inotify-tools}/bin/inotifywait -t 60 -e create -e moved_to "$QUEUE_DIR" 2>/dev/null || true
      done
    '';
  };

  # Firewall — OpenSandbox API on Tailscale
  networking.firewall.allowedTCPPorts = [ 8080 ];
}
