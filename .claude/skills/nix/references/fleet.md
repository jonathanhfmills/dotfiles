# Fleet Structure Reference

This file contains structural knowledge about the dotfiles repo layout. For
host topology and inference endpoints, always read `~/dotfiles/CLAUDE.md` at
runtime — that file is the authoritative source and is kept current.

## Repo layout

```
~/dotfiles/
├── flake.nix               # inputs, nixosConfigurations per host
├── flake.lock              # pinned input SHAs
├── CLAUDE.md               # fleet topology, inference endpoints, key commands
├── .claude/
│   ├── settings.json       # enabledPlugins (project-level, writable)
│   ├── settings.local.json # outputStyle, per-session overrides
│   └── skills/nix/         # this skill
├── modules/
│   ├── users/
│   │   └── jon.nix         # home-manager: packages, dotfiles, settings
│   └── services/           # system services (sglang, vllm, training, etc.)
├── hosts/
│   ├── desktop/
│   ├── workstation/
│   ├── nas/
│   ├── laptop/
│   └── portable/
└── pkgs/                   # custom derivations and scripts
    └── swift-training/     # GSPO training pipeline scripts
```

## Key module: modules/users/jon.nix

This is the most frequently edited file. It is shared across all hosts (imported
by each host's configuration). Host-specific branches use:

```nix
let hostname = osConfig.networking.hostName; in { ... }
```

It manages:
- `home.packages` — user-level tools
- `home.file` — managed dotfiles (settings.json, hooks, QWEN.md, etc.)
- `home.activation` — post-activation scripts
- `programs.*` — home-manager program modules (direnv, etc.)

## Settings files and their ownership

| Path | Owner | Writable at runtime? |
|------|-------|----------------------|
| `~/.claude/settings.json` | nix store symlink | No — edit `modules/users/jon.nix` |
| `~/.claude/settings.local.json` | manual / skill installs | Yes |
| `~/dotfiles/.claude/settings.json` | git (project-level) | Yes |
| `~/dotfiles/.claude/settings.local.json` | git (project-level) | Yes |
| `~/.claude/plugins/installed_plugins.json` | claude plugin CLI | Yes |

## Rebuild command

```bash
sudo nixos-rebuild switch --flake ~/dotfiles#<hostname>
```

Hostnames: `desktop`, `workstation`, `nas`, `laptop`, `portable`

Always verify with `hostname` before targeting.
