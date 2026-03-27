# Fleet Structure Reference

This file contains structural knowledge about the dotfiles repo layout. For
host topology and inference endpoints, see `knowledge/fleet-topology.md` and
`knowledge/inference-endpoints.md` — those are the authoritative sources.

## Repo layout

```
~/dotfiles/
├── agent.yaml              # Fleet gitagent manifest
├── SOUL.md                 # Shared fleet identity
├── RULES.md                # Fleet-wide hard constraints
├── DUTIES.md               # SOD policy: orchestrator/engineer/executor
├── AGENTS.md               # Framework-agnostic operating context
├── flake.nix               # inputs, nixosConfigurations per host
├── CLAUDE.md               # Claude Code context (references this structure)
├── agents/
│   ├── wanda/              # Hermes Brain (NAS orchestrator)
│   ├── cosmo/              # Engineer tier (workstation)
│   ├── coder/              # NullClaw executor
│   ├── uncertainty-manager/ # Confidence scorer
│   ├── nix-configurator/   # Sub-agent: NixOS file editing
│   ├── nix-builder/        # Sub-agent: rebuild + remediate
│   └── dashclaw/           # External: gitagent dependency
├── skills/
│   └── nix/                # /nix skill (this skill)
├── knowledge/              # Always-loaded fleet context
├── config/                 # Host operational context
├── modules/
│   ├── users/jon.nix       # home-manager: packages, dotfiles, settings
│   └── services/           # system services
├── hosts/                  # per-host hardware config
└── pkgs/                   # custom derivations
```

## Key module: modules/users/jon.nix

Most frequently edited file. Shared across all hosts.
Host-specific branches use `osConfig.networking.hostName`.

## Settings files and their ownership

| Path | Owner | Writable at runtime? |
|------|-------|----------------------|
| `~/.claude/settings.json` | nix store symlink | No — edit `modules/users/jon.nix` |
| `~/.claude/settings.local.json` | manual | Yes |
| `~/dotfiles/.claude/settings.json` | git (project-level) | Yes |
| `~/.claude/plugins/installed_plugins.json` | claude plugin CLI | Yes |

## Rebuild command

```bash
sudo nixos-rebuild switch --flake ~/dotfiles#<hostname>
```

Hostnames: `desktop`, `workstation`, `nas`, `laptop`, `portable`
