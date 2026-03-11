{ pkgs, config, lib, ... }:

let
  hostname = config.networking.hostName;
  isNas = hostname == "nas";
  isWorkstation = hostname == "workstation";
  isAgentHost = isNas || isWorkstation;

  # Which queue this host polls
  queueDir = if isNas then "queue/nas" else "queue/workstation";

  # Agent files to seed per host
  nasAgents = [ "writer" "reader" ];
  workstationAgents = [ "cosmo" "coder" "reviewer" "deployer" ];
  localAgents = if isNas then nasAgents else workstationAgents;
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
      reader-soul = builtins.path { path = ../../agents/reader/SOUL.md; name = "reader-SOUL.md"; };
      reader-agents = builtins.path { path = ../../agents/reader/AGENTS.md; name = "reader-AGENTS.md"; };
      # Workstation agents
      cosmo-identity = builtins.path { path = ../../cosmo/IDENTITY.md; name = "cosmo-IDENTITY.md"; };
      cosmo-soul = builtins.path { path = ../../cosmo/SOUL.md; name = "cosmo-SOUL.md"; };
      cosmo-user = builtins.path { path = ../../cosmo/USER.md; name = "cosmo-USER.md"; };
      cosmo-personality = builtins.path { path = ../../cosmo/personality.yaml; name = "cosmo-personality.yaml"; };
      coder-soul = builtins.path { path = ../../agents/coder/SOUL.md; name = "coder-SOUL.md"; };
      coder-agents = builtins.path { path = ../../agents/coder/AGENTS.md; name = "coder-AGENTS.md"; };
      reviewer-soul = builtins.path { path = ../../agents/reviewer/SOUL.md; name = "reviewer-SOUL.md"; };
      reviewer-agents = builtins.path { path = ../../agents/reviewer/AGENTS.md; name = "reviewer-AGENTS.md"; };
      deployer-soul = builtins.path { path = ../../agents/deployer/SOUL.md; name = "deployer-SOUL.md"; };
      deployer-agents = builtins.path { path = ../../agents/deployer/AGENTS.md; name = "deployer-AGENTS.md"; };
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

    '' + (if isNas then ''
      # NAS agents: writer, reader
      mkdir -p /var/lib/orchestrator/agents/{writer,reader}/{memory,specialists}

      seed_file /var/lib/orchestrator/agents/writer/SOUL.md ${writer-soul}
      seed_file /var/lib/orchestrator/agents/writer/AGENTS.md ${writer-agents}
      seed_memory /var/lib/orchestrator/agents/writer/MEMORY.md "Writer"

      seed_file /var/lib/orchestrator/agents/reader/SOUL.md ${reader-soul}
      seed_file /var/lib/orchestrator/agents/reader/AGENTS.md ${reader-agents}
      seed_memory /var/lib/orchestrator/agents/reader/MEMORY.md "Reader"
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

      # Reviewer
      seed_file /var/lib/orchestrator/agents/reviewer/SOUL.md ${reviewer-soul}
      seed_file /var/lib/orchestrator/agents/reviewer/AGENTS.md ${reviewer-agents}
      seed_memory /var/lib/orchestrator/agents/reviewer/MEMORY.md "Reviewer"

      # Deployer
      seed_file /var/lib/orchestrator/agents/deployer/SOUL.md ${deployer-soul}
      seed_file /var/lib/orchestrator/agents/deployer/AGENTS.md ${deployer-agents}
      seed_memory /var/lib/orchestrator/agents/deployer/MEMORY.md "Deployer"
    '');
  };

  # Agent runner — polls local queue, spawns Nullclaw sandboxes via opensandbox API
  systemd.services.agent-runner = {
    description = "Agent Runner — Nullclaw task executor (${hostname}, polls ${queueDir})";
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

      echo "Agent runner started — polling $QUEUE_DIR"

      process_task() {
        local task_file="$1"
        local task_id=$(basename "$task_file" .json)
        local agent=$(jq -r '.agent // "unknown"' "$task_file")

        echo "Processing task $task_id (agent: $agent)"

        # Determine agent identity dir
        local agent_dir="$AGENTS_DIR/$agent"
        if [ ! -d "$agent_dir" ]; then
          echo "Unknown agent: $agent — skipping"
          mv "$task_file" "$RESULTS_DIR/$task_id.error.json"
          return
        fi

        # Spawn Nullclaw sandbox for this agent
        local SANDBOX_ID=$(curl -sf -X POST http://localhost:8080/v1/sandboxes \
          -H 'Content-Type: application/json' \
          -d "{
            \"image\": {\"uri\": \"ghcr.io/nullclaw/nullclaw:latest\"},
            \"timeout\": 1800,
            \"resourceLimits\": {\"cpu\": \"500m\", \"memory\": \"1Gi\"},
            \"entrypoint\": [\"nullclaw\", \"run\", \"/home/user/task.json\"],
            \"volumes\": [
              {\"name\": \"agent-identity\", \"host\": {\"path\": \"$agent_dir\"}, \"mountPath\": \"/home/user/.nullclaw/identity\"},
              {\"name\": \"task-input\", \"host\": {\"path\": \"$task_file\"}, \"mountPath\": \"/home/user/task.json\", \"readOnly\": true}
            ]
          }" | jq -r '.id' 2>/dev/null)

        if [ -z "$SANDBOX_ID" ] || [ "$SANDBOX_ID" = "null" ]; then
          echo "Failed to spawn sandbox for $agent"
          mv "$task_file" "$RESULTS_DIR/$task_id.error.json"
          return
        fi

        echo "Spawned $agent sandbox: $SANDBOX_ID"

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
        echo "Task $task_id completed"
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
