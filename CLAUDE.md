# NixOS Fleet — Claude Code Context

This repo is a [gitagent](https://github.com/open-gitagent/gitagent) monorepo.
Fleet identity lives in `SOUL.md`, constraints in `RULES.md`, agent hierarchy in `agents/`.

## Fleet

Run `sudo tailscale status` for live IPs and connectivity. See `knowledge/fleet-topology.md` for host roles and hardware.

## Inference

See `knowledge/inference-endpoints.md` for endpoints and operational commands.

## NixOS Configuration

For any NixOS change, use the `/nix` skill. Full instructions: `skills/nix/SKILL.md`.

## Agents

| Agent | Location | Scope |
|-------|----------|-------|
| Hermes Brain | `agents/wanda/` | NAS |
| Engineer | `agents/cosmo/` | Workstation |
| NullClaw Coder | `agents/coder/` | NAS + Workstation |
| Confidence Scorer | `agents/uncertainty-manager/` | NAS |
| NixOS Configurator | `agents/nix-configurator/` | All dev hosts |
| NixOS Builder | `agents/nix-builder/` | All dev hosts |
| DashClaw Expert | `agents/dashclaw/` | All (gitagent dependency) |

## Memory

After sessions, consolidate learnings into `~/.claude/projects/-home-jon-dotfiles/memory/MEMORY.md`.
