# Fleet Topology

## Hosts

| Host | Tailscale IP | Hardware | Role |
|------|-------------|----------|------|
| **desktop** | `100.74.117.36` | Intel iGPU | Daily driver |
| **workstation** (Cosmo) | `100.87.216.16` | RTX 3080 10GB, 8700K CPU | Agent compute + training |
| **nas** (Wanda) | `100.95.201.10` | AMD 9070 XT 16GB, ZFS NAS | Brain + orchestrator |
| **laptop** | `100.104.109.104` | Intel Iris Xe | Mobile dev |
| **portable** | dynamic | — | Field device |

## Syncthing

Cosmo → Wanda (trajectories, LoRA adapters). Both machines sync `/var/lib/vllm/models/`.

## Docs Index

| File | Contents |
|------|----------|
| `docs/INFERENCE.md` | Model map, engines, quantization pipeline, LoRA hot-swap |
| `docs/TRAINING.md` | GSPO pipeline, Atropos RL, GEPA, trajectory format |
| `docs/AGENTS.md` | MoE architecture, NullClaw, routing tiers, MCP servers |
