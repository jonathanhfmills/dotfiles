# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
make install        # full bootstrap on a fresh machine
make update         # apt-get update && upgrade
make apt-repos      # register all third-party apt repos/keys (run before individual tool installs)
make <target>       # install a single tool (e.g. make codex, make docker)
make link           # stow git + tmux configs into $HOME
make proxy          # start Caddy reverse proxy stack (docker compose up -d)
```

## Architecture

**Makefile** is the single entry point. All targets are idempotent — guarded with `command -v` or file existence checks. The `install` target chains all default targets.

**apt-repos** centralizes third-party apt repo/key registration (GitHub CLI, Claude Code, Microsoft, Docker). Tool targets (`gh`, `claude`, `func`, `docker`) depend on it and only run `apt-get install`.

**Stow packages** — `git/` and `tmux/` mirror `$HOME` layout exactly. `make link` stows both. `git/.gitconfig` is gitignored (personal identity/signing key); `git/.gitconfig.example` is the tracked template — `make link` copies it to `git/.gitconfig` if absent.

**npm tool targets** (`codex`, `gemini`, `qwen`, `sisyphus`) are opt-in standalone targets, not part of `make install`. Only `@anthropic-ai/sandbox-runtime` installs by default via `npm-globals`.

**proxy/** is a Docker Compose Caddy stack — not a stow package. Add new local sites by appending a block to `proxy/Caddyfile` and joining the target container to the `proxy` Docker network.

## Makefile Conventions

- Idempotency guard: `@if ! command -v <tool> &>/dev/null; then ... else echo "already installed"; fi`
- Apt repo pattern: write key to `/etc/apt/keyrings/`, write `.list` to `/etc/apt/sources.list.d/`, then `apt-get update`
- New tool with dotfiles: create `toolname/` stow package mirroring `$HOME`, add to `link:` target
- All targets must appear in `.PHONY`
