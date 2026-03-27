---
name: nix
description: >
  Make any NixOS configuration change through the ~/dotfiles flake. Use this skill
  whenever the user wants to install or remove packages, change system or user
  configuration, modify Claude Code settings or plugins, add or update services,
  write activation scripts, bump flake inputs, or make any OS-level change that
  needs to persist. This skill owns the full workflow: discover context → find the
  right file → edit → rebuild with confirmation → verify → commit. Invoke proactively
  any time the user says "install X", "add Y to nix", "configure Z", or anything that
  would touch a .nix file or the OS state — even if they don''t say "Nix" explicitly.
---

# NixOS Configuration Skill

You own all NixOS configuration changes through the `~/dotfiles` flake. The full
workflow is: orient → locate → change → rebuild → verify → commit.

## 1. Orient

Discover context at runtime — never rely on hardcoded fleet details:

```bash
hostname                     # current machine
cat ~/dotfiles/CLAUDE.md     # fleet topology, host roles, inference endpoints
```

Identify the target host. Default to the current machine and confirm before
rebuilding:

> "I'll rebuild **`<hostname>`** — correct?"

Read `skills/nix/references/fleet.md` if you need a deeper map of the repo structure.

## 2. Locate the right file

| What's changing | File |
|-----------------|------|
| User packages, dotfiles, home-manager settings | `modules/users/jon.nix` |
| Claude Code `settings.json` | `modules/users/jon.nix` → `home.file.".claude/settings.json"` |
| Claude Code plugins | `claude plugin install` + `.claude/settings.json` |
| System services | `modules/services/<name>.nix` or `hosts/<hostname>/` |
| Flake inputs | `flake.nix` + `nix flake update [input]` |

When unsure: `grep -r "<keyword>" ~/dotfiles --include="*.nix" -l`

Read `skills/nix/references/patterns.md` for detailed examples of each change type.

## 3. Make the change

Keep changes minimal and consistent with the existing style in the file you're
editing. Read the surrounding context before writing.

**Key constraint:** `~/.claude/settings.json` is a read-only nix store symlink.
Edit the `home.file.".claude/settings.json".text` block in `modules/users/jon.nix`
instead, then rebuild. The same applies to any other `home.file`-managed path.

For plugin installation, see `skills/nix/references/patterns.md` → "Claude Code plugins".

Read `skills/nix/references/anti-patterns.md` before rebuilding if this is the first
change of a given type — it documents failure modes that are easy to hit.

## 4. Rebuild with confirmation

Confirm the hostname, then:

```bash
sudo nixos-rebuild switch --flake ~/dotfiles#<hostname>
```

Expected output includes `warning: Git tree '...' is dirty` — this is normal.

If activation fails with `home-manager-jon.service: Failed`:
```bash
journalctl -fu home-manager-jon --no-pager | tail -30
```
The real error is almost always a file conflict or bad nix expression. See
`skills/nix/references/anti-patterns.md` for remediation.

## 5. Verify

After a successful rebuild, ask the user to confirm the change behaves correctly
before touching git. For functional changes (services, tools), suggest a quick
smoke test.

## 6. Commit and push

Once verified, use the `/commit` skill to create a focused commit. For changes
that should propagate to other fleet hosts (anything in `modules/users/` is
shared across all hosts), use `/commit-push-pr` to open a PR for review.

For larger features — new services, significant refactors, multi-file changes —
use `/feature-dev` to plan before editing.

---

## Hard rules

- Never edit paths under `/nix/store/` — they are immutable
- Never use `git add -A` — stage files explicitly to avoid committing secrets
- One logical change per commit — clean rollback if a host breaks
- Test on `laptop` first — it's the safe canary before pushing to `workstation` or `nas`
- Use `#!/usr/bin/env bash` in any shell scripts — NixOS has no `/bin/bash`
