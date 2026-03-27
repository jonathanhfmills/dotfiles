# NixOS Fleet — Claude Code Context

## Fleet

| Host | Tailscale IP | Hardware | Role |
|------|-------------|----------|------|
| **desktop** | `100.74.117.36` | Intel iGPU | Daily driver |
| **workstation** (Cosmo) | `100.87.216.16` | RTX 3080 10GB, 8700K CPU | Agent compute + training |
| **nas** (Wanda) | `100.95.201.10` | AMD 9070 XT 16GB, ZFS NAS | Brain + orchestrator |
| **laptop** | `100.104.109.104` | Intel Iris Xe | Mobile dev |
| **portable** | dynamic | — | Field device |

## Inference

| Endpoint | Model | Engine | Role |
|----------|-------|--------|------|
| `Wanda:11434` | Crow-9B (fp8) | SGLang ROCm | Primary inference — Hermes brain |
| `Cosmo:11434` | Qwen3.5-9B-PARO (INT4) | vLLM CUDA | NullClaw experts, tool calling |
| `Cosmo:11436` | Qwen3.5-0.8B (INT4) | vLLM CPU | Classifier, fast routing |
| `Wanda:11435` | Qwen3.5-35B-A3B MoE (INT4) | SGLang CPU | GSPO scorer — overnight only |

All endpoints: OpenAI-compatible API, `--api-key ollama`.

## Operational Commands

```bash
# Tail service logs
journalctl -fu sglang          # Wanda: Crow-9B inference
journalctl -fu vllm            # Cosmo: PARO-9B inference
journalctl -fu training-timer  # Nightly GSPO pipeline

# Nightly training (runs automatically at midnight on Wanda)
bash pkgs/swift-training/train-gspo.sh

# Weekly re-quantize (Cosmo, after LoRA merge)
bash pkgs/swift-training/requantize-paro.sh             # 9B ParoQuant
bash pkgs/swift-training/quantize-08b-autoround.sh      # 0.8B AutoRound
```

For NixOS configuration changes, use the `/nix` skill.

## Docs Index

| File | Contents |
|------|----------|
| `docs/INFERENCE.md` | Model map, engines, quantization pipeline, LoRA hot-swap |
| `docs/TRAINING.md` | GSPO pipeline, Atropos RL, GEPA, trajectory format |
| `docs/AGENTS.md` | MoE architecture, NullClaw, routing tiers, MCP servers |
| `QWEN.md` | Architecture discovery mode, pipeline stages, self-improvement loop |

## Syncthing Topology

Cosmo → Wanda (trajectories, LoRA adapters). Both machines sync `/var/lib/vllm/models/`.

## Memory

After sessions, consolidate learnings into `~/.claude/projects/-home-jon-dotfiles/memory/MEMORY.md`.
