# Training Pipeline: GSPO + Atropos RL

## Overview

Nightly self-improvement loop. Both machines generate trajectories during the day. Wanda trains overnight. Cosmo re-quantizes weekly. The fleet gets smarter every cycle.

```
DAYTIME — "The Data Mine"
═══════════════════════════════════════════════
Wanda (NAS):   Crow-9B fp8 (SGLang) → trajectories
Cosmo (Work):  PARO-9B INT4 (vLLM)  → trajectories
               0.8B AutoRound (CPU)  → trajectories

All trajectories → /var/lib/vllm/models/trajectories/raw/
Syncthing syncs Cosmo → Wanda

MIDNIGHT — GSPO Training (~2 hours, Wanda)
═══════════════════════════════════════════════
Phase 1: GPU generates K=4 completions/prompt (~15 min)
Phase 2: 35B-A3B MoE scores completions (~30 min, CPU)
Phase 3: ms-swift GSPO trains Crow-9B + 0.8B LoRAs (~1 hr, CPU)
Phase 4: DSPy/MIPRO prompt optimization (~15 min)
Phase 5: Weekly LoRA merge into base weights

GPU (9B) stays running throughout — no Hermes downtime.

MORNING — "The Level Up"
═══════════════════════════════════════════════
Wanda: LoRA hot-swapped onto Crow-9B (instant)
Cosmo: Weekly ParoQuant re-quantize 9B + AutoRound re-quantize 0.8B
Syncthing delivers new adapters/weights automatically
```

## GSPO (Group Sequence Policy Optimization)

The same algorithm Alibaba used to train Qwen3. Implemented via [ms-swift](https://github.com/modelscope/ms-swift) v4.0+.

### How it works

1. Crow-9B generates K=4 completions per prompt (GPU, fast)
2. 35B-A3B MoE scores each completion (CPU, just numbers — not full responses)
3. GSPO ranks completions within each group and trains on relative preferences
4. Student learns which of its OWN responses was best — self-improvement via teacher scoring

### Why GSPO over GRPO

- Sequence-level optimization (full reasoning chains, not individual tokens)
- Won't collapse on long runs (GRPO degrades, GSPO scales with compute)
- No reference model needed → less RAM than DPO
- Precision-tolerant — handles INT4 quantization gracefully

### Why standalone Crow-9B during the day

Running the student alone during the day ensures **genuine mistakes** in the training data. If a teacher "helps" during the day, mistakes are half-corrected and the data becomes muddy. Clean data = better training signal.

## Training Script

**`pkgs/swift-training/train-gspo.sh`**

```bash
# Nightly GSPO pipeline
bash pkgs/swift-training/train-gspo.sh
```

Targets:
- **Crow-9B** (`crownelius/Crow-9B-Opus-4.6-Distill-Heretic_Qwen3.5`) — LoRA rank 16
- **0.8B** (`Qwen/Qwen3.5-0.8B`) — LoRA rank 8

Weekly LoRA merge: every 7 training runs, merges LoRA into Crow-9B base weights and drops a `.ready-for-requant` marker for Cosmo.

## 35B-A3B MoE Scorer

MoE architecture: 35B total params, **3B active per token**. Used for scoring ONLY — reward/punishment signal. Too slow for inference (~2-5 tok/s on CPU), accurate enough for evaluation (~96% quality at INT4).

- **Service:** `modules/services/sglang-evaluator.nix`
- **Port:** 11435
- **NOT auto-started** — training timer starts/stops it
- **Requires:** 32GB RAM on NAS (17.5GB model + OS/ZFS)

## DQN Checkpoint/Rollback

Training is self-correcting:

```
Checkpoint current model weights
    │
    ▼
Train QLoRA on scored trajectories (reward >= 7.0)
    │
    ▼
Evaluate on held-out test set (10%)
    │
    ├── Improved → save checkpoint, deploy adapter
    │
    └── Degraded → rollback to checkpoint, try different:
                    - hyperparams (lr, rank, alpha)
                    - training data subset
                    - filtering threshold
```

Hermes (Brain) learns from training failures via MEMORY.md — avoids repeating bad configs.

## Quantization Scripts

| Script | What | Where | When |
|--------|------|-------|------|
| `requantize-paro.sh` | ParoQuant INT4 for Crow-9B | Cosmo GPU | Weekly |
| `quantize-08b-autoround.sh` | AutoRound INT4 for 0.8B | Cosmo CPU | Weekly |
| `test-quantization.sh` | Verify both methods work | Cosmo | Before first training |

## Timer

**`modules/services/training-timer.nix`** — nightly cron at midnight on Wanda.

GPU stays running throughout. Syncthing delivers updated LoRAs to Cosmo automatically.

## Atropos RL

[Nous Research Atropos](https://github.com/NousResearch/Atropos) — async RL framework for tool-calling agents.

- `HermesAgentBaseEnv` for Hermes trajectories
- `qwen3_coder` parser built in
- GRPO training integration
- Tinker-Atropos for LoRA fine-tuning

**Custom environment:** `environments/claw-army-env.py`

## GEPA Self-Evolution

DSPy + GEPA (Genetic-Pareto Prompt Evolution) evolves skills, tool descriptions, system prompts **without GPU training** (~$2-10 per optimization run via API).

- **Atropos** = updates model weights (gradient-based)
- **GEPA** = updates prompts/skills/tools (parameter-free, text mutations)
- Complementary — both improve the fleet through different mechanisms

## DSPy/MIPRO

**`pkgs/dspy-optimizer/optimize.py`**

Bayesian prompt optimization. ~800 API calls to the local 9B model. 15-30 min. Runs as Phase 4 of nightly pipeline (after GSPO, using freshly-trained adapter).

## Trajectory Format

```json
{
  "tool": "tool_name",
  "input": {"arg": "value"},
  "output": "result",
  "backend": "nullclaw-9b",
  "business": "client-name",
  "timestamp": 1710460800
}
```

Backend values: `nullclaw-9b`, `nullclaw-08b`, `nullclaw-grunt`, `acp-qwen-code`, `acp-claude-code`, etc.

Trajectories stored in:
- `/var/lib/vllm/models/trajectories/raw/` — unscored
- `/var/lib/vllm/models/trajectories/scored/` — after 35B evaluation
- `/var/lib/vllm/models/adapters/` — trained LoRA adapters
- `/var/lib/vllm/models/merged-crow-9b/` — merged weights for re-quantization

## Per-Business Learning

Trajectories tagged by `BUSINESS_CONTEXT` env var:

```
trajectories/business-a/  → adapters/business-a.safetensors
trajectories/business-b/  → adapters/business-b.safetensors
```

SGLang supports LoRA hot-swap — switch adapters per request. The longer you work with a client, the less frontier API is needed.

## The Compounding Loop

```
Day 1:   Local solves 60%, frontier solves 40%
Week 2:  Local solves 80%, frontier costs drop
Month 2: Local solves 95%, near-zero API spend

Every frontier call is logged → scored → trained on.
The gap never fully closes (35B > 9B capacity) = permanent training signal.
Knowledge compounds forever.
```

## Files

| File | Purpose |
|------|---------|
| `pkgs/swift-training/train-gspo.sh` | Nightly GSPO orchestrator |
| `pkgs/swift-training/requantize-paro.sh` | ParoQuant re-quantize 9B |
| `pkgs/swift-training/quantize-08b-autoround.sh` | AutoRound re-quantize 0.8B |
| `pkgs/swift-training/test-quantization.sh` | Quantization test suite |
| `pkgs/gspo-generator/generate_completions.py` | GPU: generate K completions |
| `pkgs/gspo-generator/score_completions.py` | CPU: score with 35B |
| `pkgs/dspy-optimizer/optimize.py` | MIPRO prompt optimization |
| `pkgs/trajectory-logger/logger.py` | Trajectory capture proxy |
| `pkgs/trajectory-logger/logger.py` | Trajectory logging service |
| `modules/services/training-timer.nix` | Nightly cron timer |
| `modules/services/sglang-evaluator.nix` | 35B-A3B scorer service |
| `modules/services/trajectory-logger.nix` | Trajectory capture service |
| `environments/claw-army-env.py` | Atropos RL environment |
| `workflows/rl-training.yaml` | RL training triggers |
