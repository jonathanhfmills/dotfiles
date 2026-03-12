{ pkgs, config, lib, ... }:

let
  hostname = config.networking.hostName;
  isNas = hostname == "nas";
  isWorkstation = hostname == "workstation";
  isAgentHost = isNas || isWorkstation;

  # Which queue this host polls
  # Desktop takes over workstation's queue (same agents, same role)
  queueDir = if isNas then "queue/nas" else "queue/workstation";

  # Agent files to seed per host
  nasAgents = [ "writer" "reader" ];
  workstationAgents = [ "cosmo" "coder" "reviewer" "deployer" ];
  localAgents = if isNas then nasAgents else workstationAgents;

  # Per-agent CLI command (which LLM reasoning engine to use)
  # OpenSandbox IS the sandbox — no --sandbox docker needed
  agentCli = {
    cosmo = "claude --acp";
    coder = "qwen --acp --auth-type=openai";
    reviewer = "claude --acp";
    deployer = "qwen --acp --auth-type=openai";
    writer = "qwen --acp --auth-type=openai";
    reader = "qwen --acp --auth-type=openai";
  };

  # Both agent hosts use local ollama — NAS: 9070 XT Vulkan, Workstation: RTX 3080 CUDA
  ollamaModel = "qwen3.5:9b";
  ollamaBaseUrl = "http://localhost:11434";       # host-side (qwen settings, direct access)
  ollamaDockerUrl = "http://172.17.0.1:11434";    # container-side (Docker bridge to host)
  # Settings written to agent workspace — read inside Docker containers, so use bridge URL
  agentSettingsJson = builtins.toJSON {
    modelProviders.openai = [{
      id = ollamaModel;
      name = "${ollamaModel} (${hostname} ollama)";
      envKey = "QWEN_API_KEY";
      baseUrl = "${ollamaDockerUrl}/v1";
    }];
    security.auth.selectedType = "openai";
    model.name = ollamaModel;
    general.enableAutoUpdate = false;
    privacy.usageStatisticsEnabled = false;
    telemetry.enabled = false;
    tools.approvalMode = "yolo";
    output.format = "json";
  };
in
lib.mkIf isAgentHost {
  # Agent workspace directories (persist across nixos-rebuild)
  systemd.tmpfiles.rules =
    let
      agentDirs = builtins.concatMap (name: [
        "d /var/lib/orchestrator/agents/${name} 0755 root root -"
        "d /var/lib/orchestrator/agents/${name}/memory 0755 root root -"
        "d /var/lib/orchestrator/agents/${name}/specialists 0755 root root -"
      ]) localAgents;
    in [
      "d /var/lib/orchestrator 0755 root root -"
      "d /var/lib/orchestrator/agents 0755 root root -"
      # Shared dir — Syncthing syncs this between NAS and workstation
      "d /var/lib/orchestrator/shared 0755 root root -"
      "d /var/lib/orchestrator/shared/queue 0755 root root -"
      "d /var/lib/orchestrator/shared/queue/nas 0755 root root -"
      "d /var/lib/orchestrator/shared/queue/workstation 0755 root root -"
      "d /var/lib/orchestrator/shared/queue/results 0755 root root -"
    ] ++ agentDirs;

  # Seed agent identity files (only if not already present — preserves growth)
  system.activationScripts.agent-runner-seed =
    let
      # NAS agents
      writer-soul = builtins.path { path = ../../agents/writer/SOUL.md; name = "writer-SOUL.md"; };
      writer-agents = builtins.path { path = ../../agents/writer/AGENTS.md; name = "writer-AGENTS.md"; };
      writer-qwen = builtins.path { path = ../../agents/writer/QWEN.md; name = "writer-QWEN.md"; };
      reader-soul = builtins.path { path = ../../agents/reader/SOUL.md; name = "reader-SOUL.md"; };
      reader-agents = builtins.path { path = ../../agents/reader/AGENTS.md; name = "reader-AGENTS.md"; };
      reader-qwen = builtins.path { path = ../../agents/reader/QWEN.md; name = "reader-QWEN.md"; };
      # Workstation agents
      cosmo-identity = builtins.path { path = ../../cosmo/IDENTITY.md; name = "cosmo-IDENTITY.md"; };
      cosmo-soul = builtins.path { path = ../../cosmo/SOUL.md; name = "cosmo-SOUL.md"; };
      cosmo-user = builtins.path { path = ../../cosmo/USER.md; name = "cosmo-USER.md"; };
      cosmo-personality = builtins.path { path = ../../cosmo/personality.yaml; name = "cosmo-personality.yaml"; };
      coder-soul = builtins.path { path = ../../agents/coder/SOUL.md; name = "coder-SOUL.md"; };
      coder-agents = builtins.path { path = ../../agents/coder/AGENTS.md; name = "coder-AGENTS.md"; };
      coder-qwen = builtins.path { path = ../../agents/coder/QWEN.md; name = "coder-QWEN.md"; };
      reviewer-soul = builtins.path { path = ../../agents/reviewer/SOUL.md; name = "reviewer-SOUL.md"; };
      reviewer-agents = builtins.path { path = ../../agents/reviewer/AGENTS.md; name = "reviewer-AGENTS.md"; };
      reviewer-qwen = builtins.path { path = ../../agents/reviewer/QWEN.md; name = "reviewer-QWEN.md"; };
      deployer-soul = builtins.path { path = ../../agents/deployer/SOUL.md; name = "deployer-SOUL.md"; };
      deployer-agents = builtins.path { path = ../../agents/deployer/AGENTS.md; name = "deployer-AGENTS.md"; };
      deployer-qwen = builtins.path { path = ../../agents/deployer/QWEN.md; name = "deployer-QWEN.md"; };
    in {
    text = ''
      seed_file() {
        local dest="$1"
        local src="$2"
        if [ ! -f "$dest" ]; then
          cp "$src" "$dest"
          echo "Seeded $dest"
        fi
      }

      overwrite_file() {
        local dest="$1"
        local content="$2"
        mkdir -p "$(dirname "$dest")"
        echo "$content" > "$dest"
        echo "Wrote $dest"
      }

      seed_memory() {
        local dest="$1"
        local name="$2"
        if [ ! -f "$dest" ]; then
          cat > "$dest" << SEED
# MEMORY.md — $name

*This file is mine. I update it as I learn.*

## Patterns

## Preferences

## Lessons
SEED
          echo "Seeded $dest"
        fi
      }

      # Qwen Code settings — always overwritten (nix-managed infra config)
      seed_qwen_config() {
        local agent_dir="$1"
        local agent_name="$2"
        local qwen_src="$3"
        mkdir -p "$agent_dir/.qwen"
        overwrite_file "$agent_dir/.qwen/settings.json" '${agentSettingsJson}'
        seed_file "$agent_dir/.qwen/QWEN.md" "$qwen_src"
      }

    '' + (if isNas then ''
      # NAS agents: writer, reader
      mkdir -p /var/lib/orchestrator/agents/{writer,reader}/{memory,specialists}

      seed_file /var/lib/orchestrator/agents/writer/SOUL.md ${writer-soul}
      seed_file /var/lib/orchestrator/agents/writer/AGENTS.md ${writer-agents}
      seed_memory /var/lib/orchestrator/agents/writer/MEMORY.md "Writer"
      seed_qwen_config /var/lib/orchestrator/agents/writer "Writer" ${writer-qwen}

      seed_file /var/lib/orchestrator/agents/reader/SOUL.md ${reader-soul}
      seed_file /var/lib/orchestrator/agents/reader/AGENTS.md ${reader-agents}
      seed_memory /var/lib/orchestrator/agents/reader/MEMORY.md "Reader"
      seed_qwen_config /var/lib/orchestrator/agents/reader "Reader" ${reader-qwen}
    '' else ''
      # Workstation agents: cosmo (lead), coder, reviewer, deployer
      mkdir -p /var/lib/orchestrator/agents/{cosmo,coder,reviewer,deployer}/{memory,specialists}

      # Cosmo — technical lead
      seed_file /var/lib/orchestrator/agents/cosmo/IDENTITY.md ${cosmo-identity}
      seed_file /var/lib/orchestrator/agents/cosmo/SOUL.md ${cosmo-soul}
      seed_file /var/lib/orchestrator/agents/cosmo/USER.md ${cosmo-user}
      seed_file /var/lib/orchestrator/agents/cosmo/personality.yaml ${cosmo-personality}
      seed_memory /var/lib/orchestrator/agents/cosmo/MEMORY.md "Cosmo"

      # Coder
      seed_file /var/lib/orchestrator/agents/coder/SOUL.md ${coder-soul}
      seed_file /var/lib/orchestrator/agents/coder/AGENTS.md ${coder-agents}
      seed_memory /var/lib/orchestrator/agents/coder/MEMORY.md "Coder"
      seed_qwen_config /var/lib/orchestrator/agents/coder "Coder" ${coder-qwen}

      # Reviewer
      seed_file /var/lib/orchestrator/agents/reviewer/SOUL.md ${reviewer-soul}
      seed_file /var/lib/orchestrator/agents/reviewer/AGENTS.md ${reviewer-agents}
      seed_memory /var/lib/orchestrator/agents/reviewer/MEMORY.md "Reviewer"
      seed_qwen_config /var/lib/orchestrator/agents/reviewer "Reviewer" ${reviewer-qwen}

      # Deployer
      seed_file /var/lib/orchestrator/agents/deployer/SOUL.md ${deployer-soul}
      seed_file /var/lib/orchestrator/agents/deployer/AGENTS.md ${deployer-agents}
      seed_memory /var/lib/orchestrator/agents/deployer/MEMORY.md "Deployer"
      seed_qwen_config /var/lib/orchestrator/agents/deployer "Deployer" ${deployer-qwen}
    '');
  };

  # Agent runner — polls local queue, spawns ACP reasoning containers via OpenSandbox API
  # Each agent gets a pluggable CLI (qwen-code default, claude/gemini for escalation)
  # OpenSandbox IS the sandbox — no inner Docker sandbox needed
  systemd.services.agent-runner = {
    description = "Agent Runner — ACP reasoning executor (${hostname}, polls ${queueDir})";
    after = [ "opensandbox-server.service" "opensandbox-pull-images.service" "network-online.target" ];
    requires = [ "opensandbox-server.service" ];
    wants = [ "network-online.target" "opensandbox-pull-images.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      RestartSec = 10;
    };
    path = [ pkgs.curl pkgs.jq pkgs.inotify-tools ];
    script = ''
      QUEUE_DIR="/var/lib/orchestrator/shared/${queueDir}"
      RESULTS_DIR="/var/lib/orchestrator/shared/queue/results"
      AGENTS_DIR="/var/lib/orchestrator/agents"

      mkdir -p "$QUEUE_DIR" "$RESULTS_DIR"

      # Syncthing folder marker + ownership (Syncthing runs as jon)
      touch /var/lib/orchestrator/shared/.stfolder
      chown -R jon:users /var/lib/orchestrator/shared

      # Wait for OpenSandbox API to be ready
      for i in $(seq 1 30); do
        if curl -sf http://localhost:8080/health > /dev/null 2>&1; then
          break
        fi
        sleep 2
      done

      # Read Wanda's proxy port for OpenClaw endpoint (NAS only, read once at startup)
      WANDA_PROXY_PORT="$(cat /var/lib/orchestrator/wanda-proxy-port 2>/dev/null || echo 0)"
      ${if isNas then ''
      OPENCLAW_ENDPOINT="http://172.17.0.1:''${WANDA_PROXY_PORT}/proxy/8100"
      '' else ''
      OPENCLAW_ENDPOINT="http://wanda:8100"
      ''}

      # Per-agent CLI command lookup
      # OpenSandbox IS the sandbox — no --sandbox docker flag needed
      get_agent_cli() {
        case "$1" in
          cosmo)    echo "claude --acp" ;;
          coder)    echo "qwen --acp --auth-type=openai" ;;
          reviewer) echo "claude --acp" ;;
          deployer) echo "qwen --acp --auth-type=openai" ;;
          writer)   echo "qwen --acp --auth-type=openai" ;;
          reader)   echo "qwen --acp --auth-type=openai" ;;
          *)        echo "qwen --acp --auth-type=openai" ;;
        esac
      }

      echo "Agent runner started — polling $QUEUE_DIR (OpenClaw: $OPENCLAW_ENDPOINT)"

      process_task() {
        local task_file="$1"
        local task_id=$(basename "$task_file" .json)
        local agent=$(jq -r '.agent // "unknown"' "$task_file")
        local cli_command=$(get_agent_cli "$agent")

        echo "Processing task $task_id (agent: $agent, cli: $cli_command)"

        # Determine agent identity dir
        local agent_dir="$AGENTS_DIR/$agent"
        if [ ! -d "$agent_dir" ]; then
          echo "Unknown agent: $agent — skipping"
          mv "$task_file" "$RESULTS_DIR/$task_id.error.json"
          return
        fi

        # Create per-task results directory and copy task file into it
        # (OpenSandbox mounts directories, not individual files)
        local result_dir="$RESULTS_DIR/$task_id"
        mkdir -p "$result_dir"
        cp "$task_file" "$result_dir/task.json"

        # Spawn ACP reasoning container for this agent
        # Image: acp-reasoning (pluggable brain with qwen-code + bridge)
        # Entrypoint: acp-bridge.mjs spawns the CLI internally via ACP_CLI_COMMAND
        local SANDBOX_ID=$(curl -sf -X POST http://localhost:8080/v1/sandboxes \
          -H 'Content-Type: application/json' \
          -d "{
            \"image\": {\"uri\": \"acp-reasoning:latest\"},
            \"entrypoint\": [\"${pkgs.acp-bridge}/bin/acp-bridge\"],
            \"timeout\": 1800,
            \"resourceLimits\": {\"cpu\": \"1000m\", \"memory\": \"2Gi\"},
            \"env\": {
              \"ACP_CLI_COMMAND\": \"$cli_command\",
              \"QWEN_API_KEY\": \"ollama\",
              \"OPENAI_API_KEY\": \"ollama\",
              \"OPENAI_BASE_URL\": \"${ollamaDockerUrl}/v1\",
              \"OLLAMA_BASE_URL\": \"${ollamaDockerUrl}\",
              \"OPENCLAW_ENDPOINT\": \"$OPENCLAW_ENDPOINT\",
              \"AGENT_NAME\": \"$agent\",
              \"WORKSPACE\": \"/workspace\",
              \"TASK_FILE\": \"/workspace/results/task.json\",
              \"HOME\": \"/workspace/agent\"
            },
            \"networkPolicy\": {
              \"defaultAction\": \"deny\",
              \"egress\": [
                {\"action\": \"allow\", \"target\": \"172.17.0.1:11434\"},
                ${if isNas then
                  ''{\"action\": \"allow\", \"target\": \"172.17.0.1:$WANDA_PROXY_PORT\"}''
                else
                  ''{\"action\": \"allow\", \"target\": \"100.95.201.10:8100\"}''
                },
                {\"action\": \"allow\", \"target\": \"api.anthropic.com:443\"}
              ]
            },
            \"volumes\": [
              {\"name\": \"agent-workspace\", \"host\": {\"path\": \"$agent_dir\"}, \"mountPath\": \"/workspace/agent\"},
              {\"name\": \"results\", \"host\": {\"path\": \"$result_dir\"}, \"mountPath\": \"/workspace/results\"}
            ]
          }" | jq -r '.id' 2>/dev/null)

        if [ -z "$SANDBOX_ID" ] || [ "$SANDBOX_ID" = "null" ]; then
          echo "Failed to spawn sandbox for $agent"
          mv "$task_file" "$RESULTS_DIR/$task_id.error.json"
          return
        fi

        echo "Spawned $agent ACP reasoning sandbox: $SANDBOX_ID"

        # Wait for sandbox to complete (poll every 10s, timeout 30m)
        local elapsed=0
        while [ $elapsed -lt 1800 ]; do
          local status=$(curl -sf "http://localhost:8080/v1/sandboxes/$SANDBOX_ID" | jq -r '.status.state' 2>/dev/null)
          if [ "$status" = "Terminated" ] || [ "$status" = "Stopped" ]; then
            break
          fi
          if [ "$status" != "Running" ] && [ "$status" != "Pending" ]; then
            echo "Sandbox $SANDBOX_ID unexpected status: $status"
            break
          fi
          sleep 10
          elapsed=$((elapsed + 10))
        done

        # Move task to results
        mv "$task_file" "$RESULTS_DIR/$task_id.done.json"
        echo "Task $task_id completed (results in $result_dir)"
      }

      # Main loop: watch queue directory for new task files
      while true; do
        # Process any existing tasks first
        for task_file in "$QUEUE_DIR"/*.json; do
          [ -f "$task_file" ] || continue
          process_task "$task_file"
        done

        # Wait for new files (inotifywait with 60s timeout for fallback polling)
        inotifywait -t 60 -e create -e moved_to "$QUEUE_DIR" 2>/dev/null || true
      done
    '';
  };
}
