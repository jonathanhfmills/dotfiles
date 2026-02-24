# NixOS Fleet Configuration

Multi-host NixOS configuration managed as a Nix flake. All machines run NixOS 25.11, connect over Tailscale, and are managed from a single repo.

## Hosts

| Host | Role | Storage | Desktop | SSH |
|------|------|---------|---------|-----|
| `desktop` | Daily driver | 1TB NVMe (ext4) | COSMIC | `100.74.117.36` |
| `desktop-zfs` | Desktop ZFS variant | 1TB NVMe (ZFS) | COSMIC | same hardware |
| `workstation` | Headless gaming server | 128GB SATA boot + 2x1TB NVMe ZFS mirror | None (headless) | `100.95.201.10` |
| `portable` | USB installer/rescue | 1TB USB (ext4) | None (headless) | DHCP |
| `laptop` | Laptop (WIP) | TBD | COSMIC | TBD |

### desktop

Primary development machine. COSMIC desktop with auto-login, Steam/gamescope, GUI apps (VS Code, Chrome, Discord, Termius). Intel CPU, AMD GPU.

- **Drive:** Samsung SSD 970 EVO Plus 1TB
- **By-ID:** `nvme-Samsung_SSD_970_EVO_Plus_1TB_S4P4NG0M101390D`
- **Filesystem:** ext4 root + vfat ESP (managed by disko)
- **hostId:** `726f84c0`
- **Kernel:** LTS (ZFS compat)

The `desktop-zfs` variant uses `hardware-zfs.nix` instead for a ZFS root migration path. Same hardware, different disk layout.

### workstation

Headless gaming/streaming server. No display manager — boots to console. Always-on Sunshine remote desktop with AV1 hardware encoding (connect via Moonlight). Steam Big Picture can be launched on HDMI via SSH.

- **Boot drive:** Samsung 870 EVO 128GB (SATA) — 1G ESP only
- **Pool drives:** 2x Samsung 980 Pro OEM 1TB (NVMe) — ZFS mirror `rpool`
- **By-ID (boot):** `ata-Samsung_SSD_870_EVO_128GB_S5Y4R020S029748`
- **By-ID (nvme0):** `nvme-SAMSUNG_MZVL21T0HCLR-00A00_S6H6NA0W700362`
- **By-ID (nvme1):** `nvme-SAMSUNG_MZVL21T0HCLR-00A00_S6H6NA0W700375`
- **ZFS datasets:** `rpool/root` (`/`), `rpool/nix` (`/nix`, no snapshots), `rpool/home` (`/home`, snapshots enabled)
- **hostId:** `2f50e4ce`
- **ZFS ARC max:** 4 GB
- **Kernel:** LTS (ZFS compat)

**Session management via SSH:**
```bash
ssh workstation
session steam    # Steam Big Picture on HDMI
session stop     # Back to headless
session status   # Show what's running
```

Sunshine is always running (user lingering enabled). Connect with Moonlight anytime.

### portable

Minimal NixOS on a USB stick. Used to boot into other machines for provisioning (e.g., booted on workstation hardware to format drives and run `nixos-install`). Broad kernel module support for portability across different hardware.

- **Drive:** MILAN II 1TB (USB)
- **By-ID:** `ata-MILAN_II_1TB_181294421618`
- **Filesystem:** ext4 root + vfat ESP
- **User:** jon with `initialPassword = "changeme"`

### laptop

Work in progress. COSMIC desktop, latest kernel, no disko config yet (hardware.nix is a placeholder).

## Repo Structure

```
flake.nix                          # Flake entry point — defines all hosts
flake.lock                         # Pinned input versions

hosts/
  desktop/
    default.nix                    # COSMIC desktop, Steam, GUI apps, SSH
    hardware.nix                   # Kernel modules, CPU microcode (ext4)
    hardware-zfs.nix               # ZFS variant hardware config
    disko.nix                      # Disk layout: 1G ESP + ext4 root
  workstation/
    default.nix                    # Headless, Sunshine, Steam, session cmd
    hardware.nix                   # Kernel modules, CPU microcode
    disko.nix                      # 3-disk: SATA boot + 2x NVMe ZFS mirror
  portable/
    default.nix                    # Minimal: SSH + user only
    hardware.nix                   # Broad module support for any hardware
    disko.nix                      # Simple: 1G ESP + ext4 root
  laptop/
    default.nix                    # COSMIC desktop (WIP)
    hardware.nix                   # Placeholder

modules/
  base.nix                         # Bootloader, flakes, timezone, locale, sudo, base CLI
  networking.nix                   # NetworkManager, Tailscale, trayscale
  development.nix                  # Node.js 22, Python 3, Playwright
  programs/
    1password.nix                  # 1Password GUI + CLI + SSH agent
    ironclaw.nix                   # IronClaw AI assistant (PostgreSQL + pgvector)
  services/
    ollama.nix                     # Ollama LLM service (AMD GPU, flash attention)
    ollama-qwen3-14b-128k.modelfile
    ollama-qwen3-8b-256k.modelfile
  users/
    jon.nix                        # Home Manager: git, ssh, bash, direnv, mime
    cosmick.nix                    # Cosmick user config

scripts/
  migrate-to-zfs.sh                # ZFS migration helper
  sync-dotfiles.sh                 # Rsync dotfiles across hosts

wanda/                             # Wanda AI personality files
claude/                            # Claude Code config + custom commands
```

## Flake Inputs

| Input | Purpose |
|-------|---------|
| `nixpkgs` | NixOS 25.11 packages |
| `home-manager` | Per-user config (git, ssh, bash, direnv) |
| `disko` | Declarative disk partitioning |

## Module Matrix

Which modules each host loads:

| Module | desktop | workstation | portable | laptop |
|--------|---------|-------------|----------|--------|
| base.nix | x | x | x | x |
| networking.nix | x | x | x | x |
| development.nix | x | x | | x |
| 1password.nix | x | x | | x |
| ollama.nix | x | x | | |
| ironclaw.nix | x | x | | x |
| disko | x | x | x | x |
| home-manager | x | x | x | x |

## SSH Access

All hosts use key-only auth via 1Password SSH agent. Fleet key:
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMI/v0grXNp+qVV8TUky2BiHjHFpid6XCAA3Pg5G958Z jon@nixos-fleet
```

SSH config (managed by home-manager in `modules/users/jon.nix`):
```
Host desktop      → 100.74.117.36  (Tailscale)
Host workstation  → 100.95.201.10  (Tailscale)
Host portable     → portable       (LAN/mDNS)
```

Desktop and workstation bind sshd exclusively to their Tailscale IPs. sshd starts after `tailscaled.service` with a 5s restart delay.

## Disko

Disko manages disk layouts declaratively. Each host has a `disko.nix` that defines partitions using stable `/dev/disk/by-id/` paths.

**Important:** The disko NixOS module only generates `fileSystems`/`swapDevices` config during `nixos-rebuild switch`. It does NOT reformat disks. Reformatting only happens with the `disko` CLI:
```bash
# Format disks (DESTRUCTIVE)
sudo disko --mode disko /path/to/disko.nix

# Just mount (non-destructive)
sudo disko --mode mount /path/to/disko.nix
```

## Common Operations

```bash
# Rebuild current host (from desktop)
sudo nixos-rebuild switch --flake ~/dotfiles#desktop

# Rebuild remote host
rsync -a ~/dotfiles/ jon@workstation:/tmp/dotfiles/
ssh workstation "cd /tmp/dotfiles && git init && git add -A && git commit -m sync && sudo nixos-rebuild switch --flake /tmp/dotfiles#workstation"

# Build without activating (test)
nixos-rebuild build --flake ~/dotfiles#desktop

# Update flake inputs
nix flake update

# Check flake
nix flake check
```

## Adding a New Host

1. Create `hosts/<name>/` with `default.nix`, `hardware.nix`, and optionally `disko.nix`
2. Add `nixosConfigurations.<name>` to `flake.nix` with the appropriate modules
3. Set `networking.hostName` and a unique `networking.hostId` (for ZFS: `head -c 8 /dev/urandom | od -A none -t x4 | tr -d ' '`)
4. Add SSH authorized key if remote access needed
5. Add SSH matchBlock in `modules/users/jon.nix` for easy `ssh <name>` access
6. For disk provisioning: boot portable on the target hardware, format with disko, install with `nixos-install --flake /tmp/dotfiles#<name> --no-root-passwd`
