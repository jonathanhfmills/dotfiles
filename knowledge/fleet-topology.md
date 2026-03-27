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
| `knowledge/inference-endpoints.md` | Inference endpoints, operational commands |
| `agents/` | Agent identity files (SOUL.md, RULES.md, DUTIES.md per role) |
| `skills/nix/` | /nix skill — NixOS configuration patterns and anti-patterns |
