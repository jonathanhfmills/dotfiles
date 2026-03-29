# Agent Runner — spawns ACP reasoning containers via OpenSandbox API
# Polls local queue, spawns containers per task. Hermes (Brain) routes tasks
# to the right queue; agent-runner just executes them.
#
# No identity seeding — the RL loop handles learning, not static personalities.
# Cosmo identity seeded only on workstation for the Engineer tier.
{ pkgs, config, lib, ... }:

let
  hostname = config.networking.hostName;
  isNas = hostname == "nas";
  isWorkstation = hostname == "workstation";
  isAgentHost = isNas || isWorkstation;

  # Which queue this host polls
  queueDir = if isNas then "queue/nas" else "queue/workstation";

  # Both hosts now serve 9B: nas=vLLM ROCm, workstation=SGLang CUDA
  sglangModel = "Qwen/Qwen3.5-9B";
  sglangDockerUrl = "http://172.17.0.1:11434";

  # Qwen Code settings for legacy agents
  agentSettingsJson = builtins.toJSON {
    modelProviders.openai = [{
      id = sglangModel;
      name = "${sglangModel} (${hostname} SGLang)";
      envKey = "QWEN_API_KEY";
      baseUrl = "${sglangDockerUrl}/v1";
    }];
    security.auth.selectedType = "openai";
    model.name = sglangModel;
    model.parameters = {
      temperature = 0.7;
      top_p = 0.9;
      min_p = 0.05;
      frequency_penalty = 1.1;
      repeat_last_n = 64;
    };
    general.enableAutoUpdate = false;
    privacy.usageStatisticsEnabled = false;
    telemetry.enabled = false;
    tools.approvalMode = "yolo";
    output.format = "json";
  };
in
lib.mkIf isAgentHost {
  # Minimal directory structure — no per-agent identity dirs
  systemd.tmpfiles.rules = [
    "d /var/lib/orchestrator 0755 root root -"
    "d /var/lib/orchestrator/shared 0755 root root -"
    "d /var/lib/orchestrator/shared/queue 0755 root root -"
    "d /var/lib/orchestrator/shared/queue/nas 0755 root root -"
    "d /var/lib/orchestrator/shared/queue/workstation 0755 root root -"
    "d /var/lib/orchestrator/shared/queue/results 0755 root root -"
    # Workspace for sandbox containers
    "d /var/lib/orchestrator/workspace 0755 root root -"
  ] ++ (if isWorkstation then [
    # Cosmo identity on workstation (Engineer tier)
    "d /var/lib/orchestrator/cosmo 0755 root root -"
  ] else []);

  # Seed agent workspace (settings.json for qwen-code) on all agent hosts
  system.activationScripts.agent-runner-seed = {
    text = ''
      seed_file() {
        local dest="$1"
        local src="$2"
        if [ ! -f "$dest" ]; then
          cp "$src" "$dest"
          echo "Seeded $dest"
        fi
      }

      # Qwen Code settings for ACP reasoning containers
      mkdir -p /var/lib/orchestrator/workspace/.qwen
      echo '${agentSettingsJson}' > /var/lib/orchestrator/workspace/.qwen/settings.json
      cp ${builtins.path { path = ../../agents/SYSTEM.md; name = "agent-SYSTEM.md"; }} /var/lib/orchestrator/workspace/.qwen/SYSTEM.md
    '' + (if isWorkstation then ''
      # Cosmo identity on workstation (Engineer tier)
      mkdir -p /var/lib/orchestrator/cosmo
      seed_file /var/lib/orchestrator/cosmo/IDENTITY.md ${builtins.path { path = ../../agents/cosmo/IDENTITY.md; name = "cosmo-IDENTITY.md"; }}
      seed_file /var/lib/orchestrator/cosmo/SOUL.md ${builtins.path { path = ../../agents/cosmo/SOUL.md; name = "cosmo-SOUL.md"; }}
      seed_file /var/lib/orchestrator/cosmo/USER.md ${builtins.path { path = ../../agents/cosmo/USER.md; name = "cosmo-USER.md"; }}
    '' else "");
  };

  # Agent runner — polls local queue, spawns ACP reasoning containers
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
      WORKSPACE="/var/lib/orchestrator/workspace"

      mkdir -p "$QUEUE_DIR" "$RESULTS_DIR"

      # Syncthing folder marker + ownership
      touch /var/lib/orchestrator/shared/.stfolder
      chown -R jon:users /var/lib/orchestrator/shared

      # Load API keys for frontier escalation
      OPENROUTER_API_KEY=""
      if [ -f ${config.age.secrets.openrouter-api-key.path} ]; then
        source ${config.age.secrets.openrouter-api-key.path}
      fi

      # Wait for OpenSandbox API to be ready
      for i in $(seq 1 30); do
        if curl -sf http://localhost:8080/health > /dev/null 2>&1; then
          break
        fi
        sleep 2
      done

      # Backend selection: task.backend field determines CLI command
      # Hermes sets this when routing tasks to queues
      get_cli_command() {
        local backend="$1"
        case "$backend" in
          qwen-code)   echo "qwen --acp --auth-type=openai" ;;
          nullclaw)    echo "nullclaw --acp" ;;
          langgraph|*) echo "__langgraph__" ;;
        esac
      }

      echo "Agent runner started — polling $QUEUE_DIR"

      process_task() {
        local task_file="$1"
        local task_id=$(basename "$task_file" .json)
        local backend=$(jq -r '.backend // "langgraph"' "$task_file")
        local cli_command=$(get_cli_command "$backend")

        echo "Processing task $task_id (backend: $backend, cli: $cli_command)"

        local result_dir="$RESULTS_DIR/$task_id"
        mkdir -p "$result_dir"
        cp "$task_file" "$result_dir/task.json"

        local execution_mode=$(jq -r '.execution_mode // "auto"' "$task_file")
        local workflow=$(jq -r '.workflow // "sandbox_workflow"' "$task_file")

        # Spawn container — LangGraph engine or legacy ACP bridge
        local SANDBOX_ID
        if [ "$cli_command" = "__langgraph__" ]; then
          # LangGraph: run workflow script directly
          SANDBOX_ID=$(curl -sf -X POST http://localhost:8080/v1/sandboxes \
            -H 'Content-Type: application/json' \
            -d "{
              \"image\": {\"uri\": \"acp-reasoning:latest\"},
              \"entrypoint\": [\"sh\", \"-c\", \"adk-bootstrap && python3 /opt/workflows/langgraph/$workflow.py\"],
              \"timeout\": 1800,
              \"resourceLimits\": {\"cpu\": \"1000m\", \"memory\": \"2Gi\"},
              \"env\": {
                \"EXECUTION_MODE\": \"$execution_mode\",
                \"SANDBOX_DOMAIN\": \"172.17.0.1:8080\",
                \"QWEN_API_KEY\": \"ollama\",
                \"OPENAI_API_KEY\": \"ollama\",
                \"OPENAI_BASE_URL\": \"${sglangDockerUrl}/v1\",
                \"SGLANG_MODEL\": \"${sglangModel}\",
                \"OPENROUTER_API_KEY\": \"$OPENROUTER_API_KEY\",
                \"ANTHROPIC_API_KEY\": \"''${ANTHROPIC_API_KEY:-}\",
                \"IFLOW_apiKey\": \"ollama\",
                \"IFLOW_baseUrl\": \"${sglangDockerUrl}/v1\",
                \"IFLOW_modelName\": \"${sglangModel}\",
                \"TASK_FILE\": \"/workspace/results/task.json\",
                \"RESULTS_DIR\": \"/workspace/results\",
                \"HOME\": \"/workspace/agent\"
              },
              \"networkPolicy\": {
                \"defaultAction\": \"deny\",
                \"egress\": [
                  {\"action\": \"allow\", \"target\": \"172.17.0.1:11434\"},
                  {\"action\": \"allow\", \"target\": \"172.17.0.1:11435\"},
                  {\"action\": \"allow\", \"target\": \"172.17.0.1:11436\"},
                  {\"action\": \"allow\", \"target\": \"172.17.0.1:8080\"},
                  {\"action\": \"allow\", \"target\": \"openrouter.ai:443\"},
                  {\"action\": \"allow\", \"target\": \"pypi.org:443\"},
                  {\"action\": \"allow\", \"target\": \"files.pythonhosted.org:443\"}
                ]
              },
              \"volumes\": [
                {\"name\": \"workspace\", \"host\": {\"path\": \"$WORKSPACE\"}, \"mountPath\": \"/workspace/agent\"},
                {\"name\": \"results\", \"host\": {\"path\": \"$result_dir\"}, \"mountPath\": \"/workspace/results\"}
              ]
            }" | jq -r '.id' 2>/dev/null)
        else
          # Legacy ACP bridge path
          SANDBOX_ID=$(curl -sf -X POST http://localhost:8080/v1/sandboxes \
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
                \"OPENAI_BASE_URL\": \"${sglangDockerUrl}/v1\",
                \"SGLANG_MODEL\": \"${sglangModel}\",
                \"OPENROUTER_API_KEY\": \"$OPENROUTER_API_KEY\",
                \"WORKSPACE\": \"/workspace\",
                \"TASK_FILE\": \"/workspace/results/task.json\",
                \"HOME\": \"/workspace/agent\"
              },
              \"networkPolicy\": {
                \"defaultAction\": \"deny\",
                \"egress\": [
                  {\"action\": \"allow\", \"target\": \"172.17.0.1:11434\"},
                  {\"action\": \"allow\", \"target\": \"172.17.0.1:11435\"},
                  {\"action\": \"allow\", \"target\": \"openrouter.ai:443\"},
                  {\"action\": \"allow\", \"target\": \"172.17.0.1:8080\"}
                ]
              },
              \"volumes\": [
                {\"name\": \"workspace\", \"host\": {\"path\": \"$WORKSPACE\"}, \"mountPath\": \"/workspace/agent\"},
                {\"name\": \"results\", \"host\": {\"path\": \"$result_dir\"}, \"mountPath\": \"/workspace/results\"}
              ]
            }" | jq -r '.id' 2>/dev/null)
        fi

        if [ -z "$SANDBOX_ID" ] || [ "$SANDBOX_ID" = "null" ]; then
          echo "Failed to spawn sandbox for task $task_id"
          mv "$task_file" "$RESULTS_DIR/$task_id.error.json"
          return
        fi

        echo "Spawned sandbox $SANDBOX_ID for task $task_id"

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

        mv "$task_file" "$RESULTS_DIR/$task_id.done.json"
        echo "Task $task_id completed"
      }

      # Main loop
      while true; do
        for task_file in "$QUEUE_DIR"/*.json; do
          [ -f "$task_file" ] || continue
          process_task "$task_file"
        done
        inotifywait -t 60 -e create -e moved_to "$QUEUE_DIR" 2>/dev/null || true
      done
    '';
  };
}
