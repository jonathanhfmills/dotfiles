# Fleet Topology

## Live Status

For current IPs and connectivity, always run:

```bash
sudo tailscale status
```

## Hosts

| Host | Hardware | Role |
|------|----------|------|
| **desktop** | Intel iGPU | Daily driver |
| **workstation** (Cosmo) | RTX 3080 10GB, 8700K CPU | Agent compute + training |
| **nas** (Wanda) | AMD 9070 XT 16GB, ZFS NAS | Brain + orchestrator |
| **laptop** | Intel Iris Xe | Mobile dev |
| **portable** | — | Field device |

## Syncthing

Cosmo → Wanda (trajectories, LoRA adapters). Both machines sync `/var/lib/vllm/models/`.

## Docs Index

| File | Contents |
|------|----------|
| `docs/INFERENCE.md` | Model map, engines, quantization pipeline, LoRA hot-swap |
| `docs/TRAINING.md` | GSPO pipeline, Atropos RL, GEPA, trajectory format |
| `docs/AGENTS.md` | MoE architecture, NullClaw, routing tiers, MCP servers |
