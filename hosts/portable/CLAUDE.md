# Portable NixOS — Claude Guidelines

This is a USB flash drive (MILAN II 1TB). Every write shortens its lifespan.

## Rules

1. **Do all work in `/tmp/`** — it's a tmpfs (RAM). Clone repos there, build there, write scratch files there.
2. **Never write large files to disk** — no downloads, caches, or build artifacts outside `/tmp/`.
3. **Avoid unnecessary disk writes** — don't create log files, don't write to home unless persisting dotfiles changes.
4. **Keep it brief** — this host runs i3 + VS Code, minimal RAM available.
5. **Nix store is on flash** — only `nixos-rebuild` when necessary, not for experimentation.
6. **Run `nix-collect-garbage` manually** — auto GC is disabled to avoid surprise write storms.
7. **Git clone to `/tmp/`** — if you need the dotfiles repo, clone to `/tmp/dotfiles`.
8. **This host exists for emergencies** — provisioning other hosts or recovering from failures. Don't treat it as a daily driver.
