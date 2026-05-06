# ADR-0011: Per-Host Dotfiles Repos from GitHub Template

## Status
Accepted

## Context
A single `jonathanhfmills/dotfiles` repo holds all device config. As the Host Fleet grows (laptop, laptop-work, desktop, desktop-work), device-specific model paths, GPU backends, and credentials diverge. A monorepo with `hosts/` subdirectories would require conditional stow paths and per-host Makefile branches — complexity that compounds with each new host.

## Decision
Mark `jonathanhfmills/dotfiles` as a GitHub template repo. Each host gets its own derived repo: `dotfiles-laptop`, `dotfiles-laptop-work`, `dotfiles-desktop`, `dotfiles-desktop-work`. Shared improvements propagate via `git remote add upstream` + `make sync-upstream`. Per-host `.env` (gitignored) holds device-specific config (model paths, GPU backend, VRAM, credentials).

## Alternatives Considered
- **Monorepo with host dirs**: One repo, stow path per host. Less friction for shared changes but host-specific secrets bleed risk, and stow target selection logic clutters the Makefile.
- **Ansible/Nix**: Full declarative host management. Overkill for 4 personal machines; breaks the bash+make simplicity constraint of this stack.

## Consequences
- Template repo is the new upstream — PR to template, then sync to host repos via `make sync-upstream`
- `dotfiles-laptop` is first derived repo; others created once laptop config is verified working
- `sync-upstream` Makefile target required in template (propagates to all derived repos on pull)
- bicameral-mind submodule pin may diverge per host (each host can lag or advance engine version independently)
- `DISCORD_BOT_TOKEN` and model credentials live only in per-host `.env`, never committed to template
