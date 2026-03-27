# NixOS Change Patterns

## Adding a package

Verify it exists first:
```bash
nix eval nixpkgs#<package>.version 2>/dev/null || echo "not found"
# For node packages: nix eval nixpkgs#nodePackages.<package>.version
```

Then add to `home.packages` in `modules/users/jon.nix`:
```nix
home.packages = [
  pkgs.existing-package
  pkgs.new-package          # brief comment on purpose
  pkgs.nodePackages.intelephense
];
```

## Modifying Claude Code settings.json

The live `~/.claude/settings.json` is a nix store symlink — edit the source in
`modules/users/jon.nix`:

```nix
home.file.".claude/settings.json".text = builtins.toJSON {
  skipDangerousModePermissionPrompt = true;
  autoDreamEnabled = true;           # add new fields here
  model = "sonnet";
  hooks = { /* ... */ };
};
```

Rebuild to apply. The symlink updates atomically.

## Installing a Claude Code plugin

The standard `claude plugin install` writes to `settings.json` (read-only on
NixOS). Use `--scope local` instead:

```bash
# 1. Install — writes only to installed_plugins.json (writable)
claude plugin install <name>@claude-plugins-official --scope local

# 2. Enable in .claude/settings.json (project-level, writable)
# Add to enabledPlugins block:
"<name>@claude-plugins-official": true
```

The activation script in `modules/users/jon.nix` (`claudePluginPermissions`)
automatically:
- Sets `+x` on all plugin `.sh` files
- Patches `#!/bin/bash` → `#!/usr/bin/env bash`

These run on every rebuild, so new plugins don't need manual chmod.

## Adding a home-manager activation script

Runs after every `nixos-rebuild switch`, after managed files are written:

```nix
home.activation.<descriptive-name> = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
  some-command 2>/dev/null || true
'';
```

Use `|| true` to prevent activation failures from blocking the rebuild.

## Adding a system service

Create `modules/services/<name>.nix`:
```nix
{ config, pkgs, lib, ... }:
{
  systemd.services.<name> = {
    description = "...";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.<package>}/bin/<binary> <args>";
      Restart = "on-failure";
    };
  };
}
```

Then import it from the relevant host config.

## Updating a flake input

```bash
# Update one input
nix flake update claude-code

# Update all inputs
nix flake update

# Check what changed
git diff flake.lock
```

## Adding a home.file entry

For managed dotfiles:
```nix
home.file."<relative-to-home>".text = ''
  contents here
'';

# Or for executable scripts:
home.file."<path>" = {
  executable = true;
  text = ''
    #!/usr/bin/env bash
    ...
  '';
};
```

## Per-host configuration

`modules/users/jon.nix` uses `osConfig.networking.hostName` for host-specific
branches:

```nix
let
  hostname = osConfig.networking.hostName;
  isSomething = hostname == "workstation" || hostname == "nas";
in {
  home.packages = lib.optionals isSomething [ pkgs.cuda-toolkit ];
}
```
