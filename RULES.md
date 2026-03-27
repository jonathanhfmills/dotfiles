# RULES.md — Fleet Hard Constraints

## NixOS

- Never edit paths under `/nix/store/` — they are immutable
- Use `#!/usr/bin/env bash` in all shell scripts — NixOS has no `/bin/bash`
- Run `git add` before `nixos-rebuild switch` — flakes only see git-tracked files
- Test on `laptop` first — it is the safe canary before pushing to `workstation` or `nas`
- Edit `modules/users/jon.nix` for settings, never the live `~/.claude/settings.json` symlink

## Git

- Never force-push to `main`
- One logical change per commit — clean rollback if a host breaks
- Never use `git add -A` — stage files explicitly to avoid committing secrets
- Feature branches and PRs for changes that affect shared modules (`modules/users/`)

## Secrets

- Never commit API keys, tokens, or credentials to the repo
- Secrets live in agenix-encrypted `.age` files

## Escalation

- Three attempts on the same problem, then escalate — never spin
- Capture the solution when escalating to frontier models — feed it back to local weights
