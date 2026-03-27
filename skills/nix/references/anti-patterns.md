# NixOS Anti-Patterns & Remediation

## home.file conflict: "would be clobbered"

**Symptom:**
```
Existing file '/home/jon/.something' would be clobbered by a new home-manager
managed file. This is usually the result of switching to home-manager...
```

**Cause:** A plain file exists at the path home-manager wants to own as a symlink.

**Fix:**
```bash
rm /home/jon/<conflicting-path>
sudo nixos-rebuild switch --flake ~/dotfiles#<hostname>
```

The managed version will be created on the next activation.

## settings.json is read-only

**Symptom:** `claude plugin install` fails with `EACCES: permission denied` on
`/nix/store/...settings.json`.

**Cause:** `~/.claude/settings.json` is a symlink into the nix store (immutable).

**Fix:** Use `--scope local` for plugin installs. For settings changes, edit
`modules/users/jon.nix` and rebuild.

Never attempt `chmod` or direct writes on nix store paths.

## Plugin scripts: bad interpreter / permission denied

**Symptom:** `/bin/bash: bad interpreter` or `Permission denied` when running
a plugin skill.

**Cause 1:** Script has `#!/bin/bash` — NixOS has no `/bin/bash`.
**Cause 2:** Script isn't executable (marketplace syncs reset permissions).

**Fix:** Run a rebuild — the `claudePluginPermissions` activation script patches
both issues automatically. If you need it immediately without a rebuild:
```bash
find ~/.claude/plugins -name "*.sh" | while read f; do
  chmod +x "$f"
  sed -i '1s|^#!/bin/bash$|#!/usr/bin/env bash|' "$f"
done
```

## home-manager-jon.service failed

**Symptom:** `warning: the following units failed: home-manager-jon.service`

**Diagnosis:**
```bash
journalctl -fu home-manager-jon --no-pager | tail -40
```

Common causes:
- File conflict (see above)
- Syntax error in a nix expression — fix the expression, rebuild
- Missing `lib` import in a new module — add `{ pkgs, lib, ... }:` to the top

## Dirty git tree warning

**Symptom:** `warning: Git tree '/home/jon/dotfiles' is dirty`

This is **not an error** — nix evaluates the working tree even with uncommitted
changes. The build proceeds normally.

## Plugin scope confusion

**User scope** (`--scope user`) → writes to `~/.claude/settings.json` → **blocked** on NixOS.
**Project scope** (`--scope project`) → writes to `.claude/settings.json` in CWD → **works**.
**Local scope** (`--scope local`) → also writes to `.claude/settings.local.json` → **works**.

Use `--scope local` as the default for plugin installs on this fleet.

After installing, add the plugin to `enabledPlugins` in `.claude/settings.json`
(the project-level one at `~/dotfiles/.claude/settings.json`) or it won't load.

## Nix package not found

```bash
# Search for the right attribute name
nix search nixpkgs <keyword>
# Or check nodePackages specifically
nix eval nixpkgs#nodePackages.<name>.version 2>/dev/null
```

Some packages live under `pkgs.python3Packages.<name>`, `pkgs.haskellPackages.<name>`, etc.

## Rebuild targets the wrong host

`nixos-rebuild` defaults to the current hostname automatically when using
`--flake ~/dotfiles#<hostname>`. Always confirm with `hostname` before running.
