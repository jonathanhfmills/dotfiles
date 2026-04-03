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

| Agent | Location | Role |
|-------|----------|------|
| Wanda (OpenClaw) | `agents/wanda/` | Planner — orchestrates, decomposes, creates GH issues/PRs |
| Cosmo | `agents/cosmo/` | Coder/Engineer — TDD, SOLID, implementation |
| Researcher | `agents/cosmo/agents/researcher/` | Analysis — code exploration, dependency mapping |
| Reviewer | `agents/cosmo/agents/reviewer/` | Audit — security, quality, performance |
| Tester | `agents/cosmo/agents/tester/` | QA — unit/integration/E2E, FIRST principles |

## Memory

After sessions, consolidate learnings into `~/.claude/projects/-home-jon-dotfiles/memory/MEMORY.md`.
