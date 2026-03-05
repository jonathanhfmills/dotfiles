# NixOS Fleet Configuration

Multi-host NixOS configuration managed as a Nix flake. All machines run NixOS 25.11, connect over Tailscale, and are managed from a single repo.

## Hosts

| Host | Role | Storage | Desktop | SSH |
|------|------|---------|---------|-----|
| `desktop` | Daily driver | 1TB NVMe (ext4) | COSMIC | `100.74.117.36` |
| `desktop-zfs` | Desktop ZFS variant | 1TB NVMe (ZFS) | COSMIC | same hardware |
| `workstation` | Headless gaming server | 128GB SATA boot + 2x1TB NVMe ZFS mirror | None (headless) | `100.95.201.10` |
| `nas` | Storage / AI inference | 2TB NVMe (ZFS) | None (headless) | `100.87.216.16` |
| `portable` | USB installer/rescue | 1TB USB (ext4) | None (headless) | DHCP |
| `laptop` | Laptop | 512GB NVMe (ZFS) | COSMIC | `100.104.109.104` |

### desktop

Primary development machine. COSMIC desktop with auto-login, Steam/gamescope, GUI apps (Chrome, Discord, Termius). Intel CPU, AMD GPU.

- **Drive:** Samsung SSD 970 EVO Plus 1TB
- **By-ID:** `nvme-Samsung_SSD_970_EVO_Plus_1TB_S4P4NG0M101390D`
- **Filesystem:** ext4 root + vfat ESP (managed by disko)
- **hostId:** `726f84c0`
- **Kernel:** LTS (ZFS compat)

The `desktop-zfs` variant uses `hardware-zfs.nix` instead for a ZFS root migration path. Same hardware, different disk layout. ZFS variant includes dedicated datasets for Documents, Pictures, Videos, and Music.

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
- **Services:** Ollama (Vulkan, qwen3:14b), Caddy, Stremio Server, Syncthing

**Session management via SSH:**
```bash
ssh workstation
session steam    # Steam Big Picture on HDMI
session stop     # Back to headless
session status   # Show what's running
```

Sunshine is always running (user lingering enabled). Connect with Moonlight anytime.

### nas

Headless storage and AI inference server. NVIDIA RTX 3080 for CUDA-accelerated Ollama.

- **Drive:** Samsung 990 PRO 2TB (NVMe)
- **By-ID:** `nvme-Samsung_SSD_990_PRO_2TB_S7KHNJ0WC57731R`
- **ZFS datasets:** `rpool/root` (`/`), `rpool/nix` (`/nix`, no snapshots), `rpool/home` (`/home`, snapshots enabled), `rpool/stremio` (`/var/lib/stremio-server`, recordsize=16K)
- **hostId:** `c1192ca0`
- **ZFS ARC max:** 12 GB
- **Kernel:** LTS (ZFS compat)
- **GPU:** NVIDIA RTX 3080 (proprietary driver)
- **Services:** Ollama (CUDA, gemma3:12b), Caddy, Syncthing

### portable

Minimal NixOS on a USB stick. Used to boot into other machines for provisioning (e.g., booted on workstation hardware to format drives and run `nixos-install`). Broad kernel module support for portability across different hardware.

- **Drive:** MILAN II 1TB (USB)
- **By-ID:** `ata-MILAN_II_1TB_181294421618`
- **Filesystem:** ext4 root + vfat ESP
- **User:** jon with `initialPassword = "changeme"`

### laptop

COSMIC desktop laptop. Intel Iris Xe GPU, fingerprint auth for sudo, ZFS root.

- **Drive:** WD PC SN730 512GB (NVMe)
- **By-ID:** `nvme-WDC_PC_SN730_SDBQNTY-512G-1001_212198454503`
- **ZFS datasets:** `rpool/root`, `rpool/nix`, `rpool/home`, plus dedicated datasets for Documents (128K recordsize), Pictures, Videos, Music (1M recordsize)
- **hostId:** `5e8b9eaa`
- **ZFS ARC max:** 1 GB
- **Kernel:** LTS (ZFS compat)

## Repo Structure

```
flake.nix                          # Flake entry point — defines all hosts
flake.lock                         # Pinned input versions

hosts/
  desktop/
    default.nix                    # COSMIC desktop, Steam, GUI apps, SSH
    hardware.nix                   # Kernel modules, CPU microcode (ext4)
    hardware-zfs.nix               # ZFS variant hardware config + datasets
    disko.nix                      # Disk layout: 1G ESP + ext4 root
  workstation/
    default.nix                    # Headless, Sunshine, Steam, session cmd
    hardware.nix                   # Kernel modules, CPU microcode
    disko.nix                      # 3-disk: SATA boot + 2x NVMe ZFS mirror
  nas/
    default.nix                    # Headless, NVIDIA GPU, Ollama CUDA
    hardware.nix                   # Kernel modules, Intel microcode, NVIDIA
    disko.nix                      # 1G ESP + ZFS pool (2TB NVMe)
  portable/
    default.nix                    # Minimal: SSH + user only
    hardware.nix                   # Broad module support for any hardware
    disko.nix                      # Simple: 1G ESP + ext4 root
  laptop/
    default.nix                    # COSMIC desktop, Intel Iris Xe, fingerprint
    hardware.nix                   # Kernel modules, Intel microcode
    disko.nix                      # 1G ESP + ZFS pool with media datasets

modules/
  base.nix                         # Bootloader, flakes, timezone, locale, sudo, base CLI
  networking.nix                   # NetworkManager, Tailscale, trayscale
  development.nix                  # Node.js 22, Python 3, Playwright
  programs/
    1password.nix                  # 1Password GUI + CLI + SSH agent + SSH_AUTH_SOCK
    ironclaw.nix                   # IronClaw AI assistant (PostgreSQL + pgvector)
  services/
    caddy.nix                      # Caddy reverse proxy with Cloudflare DNS plugin
    dnscrypt-proxy.nix             # Encrypted DNS (Cloudflare/Google DoH, DNSSEC)
    ollama.nix                     # Ollama LLM service (Vulkan, qwen3:14b)
    ollama-nvidia.nix              # Ollama LLM service (CUDA, gemma3:12b)
    stremio-server.nix             # Stremio streaming server (hardened systemd)
    syncthing.nix                  # Syncthing per-folder sync across fleet
    ollama-qwen3-14b-128k.modelfile
    ollama-qwen3-8b-256k.modelfile
  users/
    jon.nix                        # Home Manager: git, ssh, bash, vscode, direnv, mime
    cosmic-desktop.nix             # COSMIC config (delegated to Syncthing)
    cosmick.nix                    # Cosmick user config

secrets/
  secrets.nix                      # Agenix secret definitions
  password-jon.age                 # Jon's user password
  caddy-cloudflare-token.age       # Cloudflare API token for Caddy ACME

scripts/
  migrate-to-zfs.sh                # Live ext4 → ZFS migration (desktop)
  sync-dotfiles.sh                 # Git pull/push helper

wanda/                             # Wanda AI personality files (synced to IronClaw DB)
claude/                            # Claude Code config + custom commands
```

## Flake Inputs

| Input | Purpose |
|-------|---------|
| `nixpkgs` | NixOS 25.11 packages |
| `home-manager` | Per-user config (git, ssh, bash, vscode, direnv) |
| `disko` | Declarative disk partitioning |
| `agenix` | Age-encrypted secrets management |
| `claude-code` | Claude Code CLI |

## Module Matrix

Which modules each host loads:

| Module | desktop | workstation | nas | portable | laptop |
|--------|---------|-------------|-----|----------|--------|
| base.nix | x | x | x | x | x |
| networking.nix | x | x | x | x | x |
| development.nix | x | x | x | | x |
| 1password.nix | x | x | | | x |
| ironclaw.nix | x | x | | | x |
| syncthing.nix | x | x | x | | x |
| dnscrypt-proxy.nix | x | x | x | x | x |
| caddy.nix | | x | x | | |
| ollama.nix | | x | | | |
| ollama-nvidia.nix | | | x | | |
| stremio-server.nix | | x | | | |
| disko | x | x | x | x | x |
| home-manager | x | x | x | x | x |

## Syncthing

Syncthing syncs specific folders across the fleet over Tailscale. Configured declaratively in `modules/services/syncthing.nix`.

**Shared across all hosts:**
- `ssh-config` — `/home/jon/.ssh/config.d` (fleet + client SSH host configs)

**GUI hosts only (desktop, laptop):**
- `documents` — `/home/jon/Documents`
- `pictures` — `/home/jon/Pictures`
- `videos` — `/home/jon/Videos`
- `music` — `/home/jon/Music`
- `desktop` — `/home/jon/Desktop`

COSMIC desktop configuration is also managed via Syncthing (not home-manager) — configure on one machine, it propagates to the rest.

## SSH Access

All hosts use key-only auth via 1Password SSH agent. Fleet key:
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMI/v0grXNp+qVV8TUky2BiHjHFpid6XCAA3Pg5G958Z jon@nixos-fleet
```

SSH host configs are managed by Syncthing in `~/.ssh/config.d/` and included via `~/.ssh/config`. The 1Password SSH agent socket is set globally as `SSH_AUTH_SOCK` via `modules/programs/1password.nix`.

```
Host desktop      → 100.74.117.36   (Tailscale)
Host workstation  → 100.95.201.10   (Tailscale)
Host nas          → 100.87.216.16   (Tailscale)
Host laptop       → 100.104.109.104 (Tailscale)
Host portable     → portable        (LAN/mDNS)
```

Desktop, workstation, and laptop bind sshd exclusively to their Tailscale IPs. sshd starts after `tailscaled.service` with a polling loop that waits up to 30s for Tailscale readiness.

## DNS

All hosts run dnscrypt-proxy for encrypted DNS resolution:
- **Upstream:** Cloudflare DoH (primary), Google DoH (backup)
- **DNSSEC:** Required
- **Tailscale MagicDNS:** Disabled (`--accept-dns=false`) to avoid overriding dnscrypt-proxy

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
sudo nixos-rebuild switch --flake ~/dotfiles#desktop-zfs

# Rebuild remote host
rsync -a ~/dotfiles/ jon@workstation:/tmp/dotfiles/
ssh workstation "cd /tmp/dotfiles && git init && git add -A && git commit -m sync && sudo nixos-rebuild switch --flake /tmp/dotfiles#workstation"

# Build without activating (test)
nixos-rebuild build --flake ~/dotfiles#desktop-zfs

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
5. Add Syncthing device ID to `modules/services/syncthing.nix`
6. For disk provisioning: boot portable on the target hardware, format with disko, install with `nixos-install --flake /tmp/dotfiles#<name> --no-root-passwd`
