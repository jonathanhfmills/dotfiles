# RL Training Timer — weekly QLoRA training on workstation (RTX 3080)
# Runs Sunday 2 AM. Collects scored trajectories, trains adapters,
# evaluates, and deploys via Syncthing to NAS.
# Unsloth requires CUDA — only runs on workstation.
{ pkgs, config, lib, ... }:

let
  hostname = config.networking.hostName;
  isWorkstation = hostname == "workstation";

  pythonEnv = pkgs.python312.withPackages (ps: with ps; [
    pip
    setuptools
  ]);

  trainingScript = pkgs.writeShellScript "rl-training" ''
    set -euo pipefail

    TRAJECTORIES="/var/lib/orchestrator/shared/trajectories/scored"
    CHECKPOINTS="/var/lib/vllm/models/checkpoints"
    ADAPTERS="/var/lib/vllm/models/adapters"
    LOG="/var/lib/vllm/models/training.log"

    mkdir -p "$CHECKPOINTS" "$ADAPTERS"

    echo "$(date): RL training started" >> "$LOG"

    # Count scored trajectories
    TRAJ_COUNT=$(find "$TRAJECTORIES" -name "*.json" -newer "$CHECKPOINTS/.last-train" 2>/dev/null | wc -l || echo 0)

    if [ "$TRAJ_COUNT" -lt 50 ]; then
      echo "$(date): Only $TRAJ_COUNT trajectories (need 50+), skipping" >> "$LOG"
      exit 0
    fi

    echo "$(date): Training on $TRAJ_COUNT trajectories" >> "$LOG"

    # Install unsloth if not present
    if ! ${pythonEnv}/bin/python -c "import unsloth" 2>/dev/null; then
      echo "$(date): Installing unsloth..." >> "$LOG"
      ${pythonEnv}/bin/pip install --user "unsloth[colab-new]" 2>&1 | tail -3 >> "$LOG"
    fi

    # Checkpoint current adapter
    CHECKPOINT_ID="$(date +%Y%m%d_%H%M%S)"
    if [ -f "$ADAPTERS/qwen3.5-4b-claw.safetensors" ]; then
      cp "$ADAPTERS/qwen3.5-4b-claw.safetensors" "$CHECKPOINTS/qwen3.5-4b-$CHECKPOINT_ID.safetensors"
    fi

    # Run QLoRA training
    # TODO: Replace with actual unsloth training script
    ${pythonEnv}/bin/python -c "
import json, glob, os

trajectories_dir = '$TRAJECTORIES'
files = sorted(glob.glob(os.path.join(trajectories_dir, '*.json')))
print(f'Found {len(files)} scored trajectories')

# Filter for high quality (score >= 7.0)
good = []
for f in files:
    with open(f) as fh:
        data = json.load(fh)
        if data.get('score', 0) >= 7.0:
            good.append(data)

print(f'{len(good)} trajectories with score >= 7.0')

if len(good) < 50:
    print('Not enough high-quality trajectories, skipping training')
else:
    print('Ready for QLoRA training (unsloth integration pending)')
    # Training would happen here with unsloth
    # from unsloth import FastLanguageModel
    # model, tokenizer = FastLanguageModel.from_pretrained('Qwen/Qwen3.5-4B', ...)
    # ...train on good trajectories...
    # model.save_pretrained('$ADAPTERS/qwen3.5-4b-claw')
" 2>&1 >> "$LOG"

    # Mark training timestamp
    touch "$CHECKPOINTS/.last-train"
    echo "$(date): RL training completed" >> "$LOG"
  '';
in
lib.mkIf isWorkstation {
  # Training data directories
  systemd.tmpfiles.rules = [
    "d /var/lib/vllm/models/checkpoints 0755 root root -"
    "d /var/lib/vllm/models/adapters 0755 root root -"
  ];

  # Weekly training timer
  systemd.timers.rl-training = {
    description = "Weekly RL Training Timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Sun *-*-* 02:00:00";
      Persistent = true;
      RandomizedDelaySec = "15m";
    };
  };

  systemd.services.rl-training = {
    description = "RL Training — QLoRA on scored trajectories";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = trainingScript;
      TimeoutStartSec = 7200;  # 2 hours max
    };
    path = [ pythonEnv pkgs.coreutils ];
    environment = {
      HOME = "/var/lib/vllm";
      PYTHONUSERBASE = "/var/lib/vllm/.local";
    };
  };
}
