# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Context

Before making changes, read `AGENTS.md` in the root and any relevant subdirectory. These files are the authoritative source of truth for architecture, conventions, and agent instructions. Update them when structure or behavior changes.

```
AGENTS.md           ← repo overview, all Makefile targets
git/AGENTS.md       ← git stow package, .gitconfig gitignore pattern
tmux/AGENTS.md      ← tmux stow package
proxy/AGENTS.md     ← Caddy reverse proxy stack
```

## Commands

```bash
make install        # full bootstrap on a fresh machine
make update         # apt-get update && upgrade
make <target>       # install a single tool (e.g. make codex, make docker)
make link           # stow git + tmux configs into $HOME
make proxy          # start Caddy reverse proxy stack
```

## Makefile Conventions

- All targets in `.PHONY` and idempotent (`command -v` / file existence guard)
- New apt-sourced tool → add repo/key block to `apt-repos`, tool target just runs `apt-get install`
- New tool with dotfiles → create `toolname/` stow package, add to `link:`
- Opt-in tools (not in `install`) → document as standalone targets only
