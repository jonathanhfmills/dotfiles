# Dotfiles — NixOS Fleet Configuration

You are working in Jon's NixOS fleet repository. This is a Nix flake managing multiple hosts.

## Repository Structure

```
flake.nix              — Flake entry point (inputs, host definitions)
hosts/<name>/           — Per-host configuration (configuration.nix, hardware.nix, disko.nix)
modules/programs/       — Shared program modules (1password, activitywatch, qwen-code, etc.)
modules/services/       — Shared service modules (vllm, caddy, agent-runner, etc.)
modules/users/          — User configs (jon.nix — home-manager)
pkgs/                   — Custom packages (qwen-code, etc.)
agents/                 — Agent identity files (SOUL.md, AGENTS.md per role)
cosmo/                  — Cosmo (technical lead agent) identity
scripts/                — Utility scripts
secrets/                — agenix-encrypted secrets
```

## Build & Deploy

```bash
# Build current host
sudo nixos-rebuild switch --flake ~/dotfiles

# Build specific host (dry-run)
nix build --dry-run .#nixosConfigurations.<host>.config.system.build.toplevel

# Build a package
nix build .#qwen-code

# Remote deploy (from portable or desktop)
nixos-install --flake /tmp/dotfiles#<host> --no-root-passwd
```

## Module Conventions

- `modules/programs/` — things users interact with (GUI apps, CLI tools)
- `modules/services/` — background daemons (vLLM, caddy, syncthing)
- Modules use `lib.mkIf` guards based on hostname or features
- Hardware-specific config stays in `hosts/<name>/hardware.nix`
- Secrets use agenix — encrypted in `secrets/`, decrypted at activation

## Key Patterns

- Custom packages go in `pkgs/` and are overlaid in `flake.nix`
- Home-manager config is in `modules/users/jon.nix` (not standalone)
- Per-host values use `osConfig.networking.hostName` with attrset lookups
- ZFS hosts use LTS kernel (`boot.kernelPackages = pkgs.linuxPackages`)
- Always use `by-id` disk paths in disko configs

## Testing

- `nix flake check` — validate flake structure
- `nix build --dry-run` — verify a config builds without actually building
- After changes to a service module, rebuild and check `systemctl status <service>`

## Self-Learning

If you discover a pattern or gotcha while working here, append it to your MEMORY.md.
