#!/bin/bash
# Nightly GSPO Training Pipeline (~2 hours for 100 trajectories)
#
# Phase 1: GPU generates 4 completions/prompt (~15 min)
# Phase 2: CPU scores 400 completions with 35B (~30 min)
# Phase 3: GSPO training 9B + 0.8B on CPU (~1 hour, 1 epoch)
# Phase 4: MIPRO prompt optimization (~15 min)
#
# GPU (9B) stays running throughout — no Hermes agent downtime.
set -euo pipefail

TRAJ_DIR="/var/lib/vllm/models/trajectories/raw"
SCORED_DIR="/var/lib/vllm/models/trajectories/scored"
ADAPTER_DIR="/var/lib/vllm/models/adapters"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG="/var/lib/vllm/models/gspo-training.log"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S'): $*" | tee -a "$LOG"; }

mkdir -p "$SCORED_DIR" "$ADAPTER_DIR"

# Check for raw trajectories
TRAJ_COUNT=$(find "$TRAJ_DIR" -name "*.jsonl" -newer "$ADAPTER_DIR/.last-train" 2>/dev/null | wc -l || echo 0)
if [ "$TRAJ_COUNT" -eq 0 ]; then
  log "No new trajectories since last training. Skipping."
  exit 0
fi
log "Found $TRAJ_COUNT new trajectory files"

# ── Phase 1: Generate K completions per prompt (GPU, fast) ──
log "=== Phase 1: Generating completions on GPU ==="
python3 "$SCRIPT_DIR/../gspo-generator/generate_completions.py" \
  --input-dir "$TRAJ_DIR" \
  --output-dir "$SCORED_DIR" \
  --model-url "http://localhost:11434/v1" \
  --completions-per-prompt 4

# ── Phase 2: Score completions with 35B teacher (CPU) ──
log "=== Phase 2: Starting 35B scorer ==="
systemctl start docker-sglang-evaluator
# Wait for model to load (~60s for 17.5GB INT4)
sleep 10

python3 "$SCRIPT_DIR/../gspo-generator/score_completions.py" \
  --input-dir "$SCORED_DIR" \
  --scorer-url "http://localhost:11435/v1"

log "Stopping 35B scorer to free RAM"
systemctl stop docker-sglang-evaluator
sleep 5

# ── Phase 3: GSPO training on CPU ──
SCORED_COUNT=$(cat "$SCORED_DIR"/gspo_scored_*.jsonl 2>/dev/null | wc -l || echo 0)
if [ "$SCORED_COUNT" -eq 0 ]; then
  log "No scored data. Skipping training."
  exit 0
fi

# Merge all scored data into single training file
cat "$SCORED_DIR"/gspo_scored_*.jsonl > /tmp/gspo_trainset.jsonl
log "=== Phase 3: GSPO training on $SCORED_COUNT scored groups ==="

# Train on CPU — no GPU dependency, no ROCm bitsandbytes issues
export CUDA_VISIBLE_DEVICES=""

CROW_9B="crownelius/Crow-9B-Opus-4.6-Distill-Heretic_Qwen3.5"
MERGED_DIR="/var/lib/vllm/models/merged-crow-9b"
TRAIN_COUNT_FILE="$ADAPTER_DIR/.train-count"

# Train 9B (Crow-9B — primary model, source of truth)
log "Training Crow-9B LoRA..."
swift rlhf \
  --rlhf_type gspo \
  --model "$CROW_9B" \
  --dataset /tmp/gspo_trainset.jsonl \
  --train_type lora \
  --quantization_bit 4 \
  --lora_rank 16 \
  --lora_alpha 32 \
  --lora_target_modules ALL \
  --torch_dtype bfloat16 \
  --per_device_train_batch_size 1 \
  --gradient_accumulation_steps 4 \
  --max_length 4096 \
  --num_train_epochs 1 \
  --gradient_checkpointing true \
  --learning_rate 5e-5 \
  --output_dir "$ADAPTER_DIR/9b-latest/" \
  --device cpu

# Train 0.8B (fast, small — for Cosmo CPU classifier)
log "Training 0.8B LoRA..."
swift rlhf \
  --rlhf_type gspo \
  --model Qwen/Qwen3.5-0.8B \
  --dataset /tmp/gspo_trainset.jsonl \
  --train_type lora \
  --lora_rank 8 \
  --lora_alpha 16 \
  --lora_target_modules ALL \
  --torch_dtype bfloat16 \
  --per_device_train_batch_size 4 \
  --gradient_accumulation_steps 2 \
  --max_length 2048 \
  --num_train_epochs 1 \
  --learning_rate 5e-5 \
  --output_dir "$ADAPTER_DIR/08b-latest/" \
  --device cpu

touch "$ADAPTER_DIR/.last-train"
rm -f /tmp/gspo_trainset.jsonl

# ── Phase 4: MIPRO prompt optimization ──
log "=== Phase 4: MIPRO prompt optimization ==="
python3 "$SCRIPT_DIR/../dspy-optimizer/optimize.py" --post-training || \
  log "MIPRO optimization skipped (not enough data or dspy not installed)"

# ── Phase 5: Merge LoRA into Crow-9B base (weekly) ──
# Track training count — merge every 7 runs to avoid churn
COUNT=$(cat "$TRAIN_COUNT_FILE" 2>/dev/null || echo 0)
COUNT=$((COUNT + 1))
echo "$COUNT" > "$TRAIN_COUNT_FILE"

if [ $((COUNT % 7)) -eq 0 ]; then
  log "=== Phase 5: Merging LoRA into Crow-9B base (run #$COUNT) ==="
  swift merge-lora \
    --model "$CROW_9B" \
    --adapters "$ADAPTER_DIR/9b-latest/" \
    --output_dir "$MERGED_DIR" \
    --device cpu || log "LoRA merge failed — will retry next cycle"

  if [ -f "$MERGED_DIR/config.json" ]; then
    log "Merge complete. Cosmo can re-quantize with: requantize-paro.sh"
    # Signal Cosmo via Syncthing — drop a marker file
    touch "$MERGED_DIR/.ready-for-requant"
  fi
else
  log "Skipping LoRA merge (run #$COUNT, merges every 7 runs)"
fi

# Archive processed raw trajectories
ARCHIVE_DIR="$TRAJ_DIR/archived/$(date +%Y%m%d)"
mkdir -p "$ARCHIVE_DIR"
mv "$TRAJ_DIR"/*.jsonl "$ARCHIVE_DIR/" 2>/dev/null || true

log "=== GSPO training complete. Adapters ready in $ADAPTER_DIR ==="
