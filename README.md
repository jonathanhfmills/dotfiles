# NixOS Fleet — Self-Improving Agent Infrastructure

Multi-host NixOS configuration managed as a Nix flake. All machines run NixOS 25.11, connect over Tailscale, and are managed from a single repo. The fleet runs a **three-tier agent architecture** (Brain / Engineer / Grunt) that learns from every task and trains nightly.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Hosts](#hosts)
- [Agent Infrastructure](#agent-infrastructure) → [docs/AGENTS.md](docs/AGENTS.md)
- [Inference Stack](#inference-stack) → [docs/INFERENCE.md](docs/INFERENCE.md)
- [Training Pipeline](#training-pipeline) → [docs/TRAINING.md](docs/TRAINING.md)
- [Repo Structure](#repo-structure)
- [NixOS Rebuild](#nixos-rebuild)
- [Module Matrix](#module-matrix)
- [Syncthing](#syncthing)
- [SSH Access](#ssh-access)
- [DNS](#dns)
- [Disko](#disko)
- [Adding a New Host](#adding-a-new-host)
- [Secrets](#secrets)

---

## Architecture Overview

```
                    ┌─────────────────────────────────────────┐
                    │         Hermes Agent (Brain)             │
                    │         Wanda (NAS, 9070 XT)             │
                    │  Meta-learning, routing, Atropos RL      │
                    │  Crow-9B fp8 via SGLang (ROCm)           │
                    └──────────────┬──────────────────────────┘
                                   │
                          Atlas (ACP Bridge)
                       CLI-agnostic connector
                                   │
              ┌────────────────────┼─────────────────────┐
              │                    │                     │
   ┌──────────▼──────────┐  ┌─────▼───────────┐  ┌─────▼────────────┐
   │  Qwen-Agent (Eng.)  │  │  NullClaw Fleet  │  │  OpenClaw        │
   │  Cosmo (Workstation) │  │  (Grunts)        │  │  (Skill Vetting) │
   │  PARO-9B + 0.8B AR  │  │  No identity     │  │  Default identity│
   │  vLLM (CUDA)        │  │  Disposable      │  │  Security gate   │
   └─────────────────────┘  └──────────────────┘  └──────────────────┘
```

**Two-path execution:** Local stack (qwen-code + Qwen-Agent ATIC) is source of truth. On failure, escalate to frontier models (claude-code, gemini-cli, codex-cli) using their own native tool calling. The gap between local and frontier = training signal. Nightly GSPO trains the local models to close this gap.

---

## Hosts

| Host | Tailscale | Role | GPU | Storage | Desktop |
|------|-----------|------|-----|---------|---------|
| **desktop** | `100.74.117.36` | Daily driver | Intel iGPU | 1TB NVMe (ext4) | COSMIC |
| **workstation** (Cosmo) | `100.87.216.16` | Engineer + Training | RTX 3080 10GB | 2x1TB NVMe ZFS mirror | Headless |
| **nas** (Wanda) | `100.95.201.10` | Brain + Orchestrator | AMD 9070 XT 16GB | 2TB NVMe ZFS | Headless |
| **portable** | DHCP | USB provisioning | None | 1TB USB (ext4) | Minimal i3 |
| **laptop** | `100.104.109.104` | Mobile dev | Intel Iris Xe | 512GB NVMe ZFS | COSMIC |

### Hardware Details

**Wanda (NAS)** — Intel i5-13600K, AMD Radeon 9070 XT 16GB, 24GB DDR5 (→ 32GB planned)
- Samsung 990 PRO 2TB NVMe, ZFS `rpool`
- hostId: `c1192ca0`
- Runs: SGLang (Crow-9B fp8), Hermes Brain, OpenSandbox, GSPO training

**Cosmo (Workstation)** — Intel i7-8700K, NVIDIA RTX 3080 10GB, 16GB DDR4
- 2x Samsung 980 Pro 1TB NVMe (ZFS mirror), 128GB SATA boot
- hostId: `2f50e4ce`
- Runs: vLLM (PARO-9B INT4 GPU + 0.8B AutoRound CPU), Qwen-Agent Engineer, OpenSandbox

**Desktop** — Intel CPU, Samsung 970 EVO Plus 1TB, ext4
- hostId: `726f84c0`
- COSMIC desktop, Steam/gamescope, 1Password, qwen-code

---

## Agent Infrastructure

See **[docs/AGENTS.md](docs/AGENTS.md)** for the full Brain / Engineer / Grunt architecture.

**Quick summary:**

| Role | Agent | Host | Identity |
|------|-------|------|----------|
| **Brain** | Hermes Agent | Wanda (NAS) | Wanda — orchestrator personality |
| **Engineer** | Qwen-Agent | Cosmo (Workstation) | Cosmo — builder personality |
| **Grunt** | NullClaw fleet | Any | None — disposable workers |
| **Skill Gate** | OpenClaw | Wanda | Default — infrastructure |

**Atlas** (ACP Bridge) connects all agents via JSON-RPC over stdio. `ACP_CLI_COMMAND` selects the backend (qwen-code, claude-code, gemini-cli, codex-cli), enabling cross-training across model families.

---

## Inference Stack

See **[docs/INFERENCE.md](docs/INFERENCE.md)** for model details and quantization.

| Host | Port | Model | Quant | Engine | VRAM/RAM |
|------|------|-------|-------|--------|----------|
| Wanda GPU | 11434 | Crow-9B (Opus 4.6 distill) | fp8 | SGLang (ROCm) | ~9GB / 16GB |
| Cosmo GPU | 11434 | Qwen3.5-9B-PARO | INT4 ParoQuant | vLLM (CUDA) | ~4.5GB / 10GB |
| Cosmo CPU | 11436 | Qwen3.5-0.8B | INT4 AutoRound | vLLM CPU | ~0.4GB |
| Wanda CPU | 11435 | Qwen3.5-35B-A3B MoE | INT4 | SGLang CPU | ~17.5GB (overnight only) |

All use OpenAI-compatible API with `--api-key ollama`. Tool calling via `qwen3_coder` parser.

**Crow-9B** = Claude Opus 4.6 knowledge distilled into Qwen3.5-9B with heretic uncensorship. Source of truth for training. Medical accuracy over unnecessary safeguards.

---

## Training Pipeline

See **[docs/TRAINING.md](docs/TRAINING.md)** for the full GSPO pipeline.

```
Daytime: Both machines generate trajectories
    ↓ Syncthing
Midnight (Wanda CPU, ~2 hours):
    Phase 1: GPU generates K=4 completions/prompt
    Phase 2: 35B-A3B MoE scores (reward/punishment only)
    Phase 3: ms-swift GSPO trains Crow-9B + 0.8B LoRAs
    Phase 4: DSPy/MIPRO prompt optimization
    Phase 5: Weekly LoRA merge into base weights
    ↓ Syncthing
Weekly (Cosmo GPU):
    ParoQuant re-quantize 9B → reload vLLM
    AutoRound re-quantize 0.8B → reload vLLM CPU
    ↓
Morning: Fleet is smarter than yesterday
```

**Per-business learning:** Trajectories tagged by business context. Domain-specific LoRA adapters accumulate knowledge per client. Frontier API costs decrease as local capability increases.

---

## Repo Structure

```
flake.nix                              # Entry point — all host configurations
flake.lock                             # Pinned input versions

hosts/
  desktop/                             # COSMIC desktop, Steam, GUI apps
  workstation/                         # Headless, vLLM CUDA, training
  nas/                                 # Headless, SGLang ROCm, orchestrator
  portable/                            # USB provisioning stick
  laptop/                              # COSMIC laptop

modules/
  base.nix                             # Bootloader, flakes, timezone, locale, sudo
  networking.nix                       # NetworkManager, Tailscale, WiFi
  development.nix                      # Node.js 22, Python 3, Playwright
  programs/
    1password.nix                      # 1Password + SSH agent
    activitywatch.nix                  # ActivityWatch time tracking
    nullclaw.nix                       # NullClaw binary (678KB Zig)
    qwen-code.nix                      # Qwen Code CLI
  services/
    sglang.nix                         # NAS GPU — Crow-9B fp8 (ROCm)
    sglang-nvidia.nix                  # Workstation GPU — Crow-9B (CUDA, legacy)
    sglang-evaluator.nix               # NAS CPU — 35B-A3B MoE scorer (overnight)
    sglang-classifier.nix              # 0.8B CPU classifier
    vllm-nvidia.nix                    # Workstation GPU — PARO-9B INT4 (CUDA)
    vllm-08b.nix                       # Workstation CPU — 0.8B AutoRound INT4
    vllm.nix                           # Legacy vLLM ROCm config
    vllm-nvidia.nix                    # Legacy vLLM CUDA config
    vllm-cpu.nix                       # Legacy vLLM CPU config
    llm-worker.nix                     # Legacy 0.8B CPU worker
    orchestrator.nix                   # Hermes Agent orchestrator (NAS)
    orchestrator-openclaw.nix          # OpenClaw fallback orchestrator
    opensandbox.nix                    # OpenSandbox container runtime
    agent-runner.nix                   # Task queue poller + ACP reasoning
    training-timer.nix                 # Nightly GSPO cron timer
    trajectory-logger.nix              # Trajectory capture service
    caddy.nix                          # Caddy reverse proxy (Cloudflare DNS)
    syncthing.nix                      # Syncthing per-folder sync
    dnscrypt-proxy.nix                 # Encrypted DNS (DoH, DNSSEC)
    stremio-server.nix                 # Stremio streaming server
  users/
    jon.nix                            # Home Manager: git, ssh, bash, vscode
    jon-private.nix                    # On-device-only user (no sync)
    cosmic-desktop.nix                 # COSMIC desktop config
    cosmick.nix                        # Cosmick user config
    i3-portable.nix                    # Minimal i3 for portable

pkgs/
  sglang-rocm-entrypoint.sh           # SGLang startup for ROCm (RDNA 4)
  vllm-paro-entrypoint.sh             # vLLM + ParoQuant startup for CUDA
  acp-bridge/                          # Atlas — CLI-agnostic ACP connector
  qwen-code/                           # Qwen Code Nix package
  qwen-agent/                          # Qwen-Agent ATIC + trajectory capture
  hermes-agent/                        # Hermes Agent + ACP adapter
  mcp-servers/                         # MCP servers (dispatch, escalation, memory, clawhub)
  swift-training/                      # GSPO training + quantization scripts
    train-gspo.sh                      #   Nightly GSPO pipeline
    requantize-paro.sh                 #   ParoQuant re-quantize 9B
    quantize-08b-autoround.sh          #   AutoRound re-quantize 0.8B
    test-quantization.sh               #   Test suite for quantization methods
  gspo-generator/                      # Completion generation + scoring
  dspy-optimizer/                      # MIPRO prompt optimization
  trajectory-logger/                   # Trajectory capture logger
  opensandbox-server/                  # OpenSandbox server package
  opensandbox-sdk/                     # OpenSandbox SDK package
  opensandbox-code-interpreter/        # Code interpreter for sandboxes
  google-adk/                          # Google Agent Development Kit
  aw-*/                                # ActivityWatch watchers

agents/
  SYSTEM.md                            # Base system prompt for all agents
  coder/                               # Coder agent personality
  deployer/                            # Deployer agent personality
  reader/                              # Reader agent personality
  reviewer/                            # Reviewer agent personality
  writer/                              # Writer agent personality

wanda/                                 # Wanda (Brain) identity files
  IDENTITY.md                          # Who Wanda is
  SOUL.md                              # Operating philosophy
  USER.md                              # User context
  personality.yaml                     # Personality parameters

cosmo/                                 # Cosmo (Engineer) identity files
  IDENTITY.md                          # Who Cosmo is
  SOUL.md                              # Operating philosophy
  USER.md                              # User context
  personality.yaml                     # Personality parameters

workflows/
  dispatch.yaml                        # Task routing by type
  escalation.yaml                      # 5-tier promotion chain
  rl-training.yaml                     # RL training triggers
  content-task.yaml                    # Content generation workflow
  research-task.yaml                   # Research workflow
  wp-task.yaml                         # WordPress workflow
  adk/                                 # Google ADK workflow examples

environments/
  claw-army-env.py                     # Atropos RL environment

claude/                                # Claude Code config + custom commands
secrets/                               # Agenix encrypted secrets
scripts/                               # Migration + sync scripts
```

---

## NixOS Rebuild

### Rebuild the current machine

```bash
sudo nixos-rebuild switch --flake ~/dotfiles#<hostname>
```

Examples:
```bash
# Desktop
sudo nixos-rebuild switch --flake ~/dotfiles#desktop

# Test build without activating
nixos-rebuild build --flake ~/dotfiles#desktop

# Build with verbose output
sudo nixos-rebuild switch --flake ~/dotfiles#desktop --show-trace
```

### Rebuild a remote machine

```bash
# 1. Sync dotfiles to the target
rsync -a ~/dotfiles/ jon@<host>:/tmp/dotfiles/

# 2. SSH in and rebuild
ssh <host>
cd /tmp/dotfiles
git init && git add -A && git commit -m sync
sudo nixos-rebuild switch --flake /tmp/dotfiles#<hostname>
```

Or as a one-liner:
```bash
rsync -a ~/dotfiles/ jon@workstation:/tmp/dotfiles/ && \
ssh workstation "cd /tmp/dotfiles && git init && git add -A && git commit -m sync && sudo nixos-rebuild switch --flake /tmp/dotfiles#workstation"
```

### Rollback

```bash
# Roll back to previous generation
sudo nixos-rebuild switch --rollback

# List generations
nix-env --list-generations --profile /nix/var/nix/profiles/system

# Boot into a specific generation (from GRUB menu)
# Select "NixOS - All configurations" → pick a generation
```

### Provision a new machine via Portable USB

**NEVER** run `nixos-rebuild switch --flake .#<other-host>` on the portable stick — it converts the running USB OS.

```bash
# 1. Boot portable USB on target hardware
# 2. Import/create ZFS pool
# 3. Mount target at /mnt
# 4. Copy dotfiles
rsync -a ~/dotfiles/ /tmp/dotfiles/
# 5. Install
sudo nixos-install --flake /tmp/dotfiles#<hostname> --no-root-passwd
# 6. Reboot from NVMe
```

### Update flake inputs

```bash
cd ~/dotfiles
nix flake update
sudo nixos-rebuild switch --flake .#<hostname>
```

### Validate without building

```bash
nix flake check
```

---

## Module Matrix

| Module | desktop | workstation | nas | portable | laptop |
|--------|:-------:|:-----------:|:---:|:--------:|:------:|
| base.nix | x | x | x | x | x |
| networking.nix | x | x | x | x | x |
| development.nix | x | x | x | | x |
| 1password.nix | x | | | | x |
| qwen-code.nix | x | | | | x |
| nullclaw.nix | x | | | | x |
| activitywatch.nix | x | | | | x |
| syncthing.nix | x | x | x | | x |
| dnscrypt-proxy.nix | x | x | x | x | x |
| caddy.nix | | x | x | | |
| **sglang.nix** | | | **x** | | |
| **sglang-evaluator.nix** | | | **x** | | |
| **llm-worker.nix** | | | **x** | | |
| **vllm-nvidia.nix** | | **x** | | | |
| **vllm-08b.nix** | | **x** | | | |
| **training-timer.nix** | | | **x** | | |
| **trajectory-logger.nix** | | **x** | **x** | | |
| **opensandbox.nix** | | **x** | **x** | | |
| **orchestrator.nix** | | | **x** | | |
| **agent-runner.nix** | | **x** | **x** | | |
| stremio-server.nix | | x | | | |
| disko | x | x | x | x | x |
| home-manager | x | x | x | x | x |

---

## Syncthing

Declaratively configured in `modules/services/syncthing.nix`. Syncs over Tailscale.

**All hosts:** `ssh-config` — `/home/jon/.ssh/config.d`

**GUI hosts (desktop, laptop):** Documents, Pictures, Videos, Music, Desktop

**AI hosts (NAS, workstation):** Trajectories, adapters, and merged model weights sync between Wanda and Cosmo for the training pipeline.

COSMIC desktop config syncs via Syncthing (not home-manager).

---

## SSH Access

Key-only auth via 1Password SSH agent. Fleet key:
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMI/v0grXNp+qVV8TUky2BiHjHFpid6XCAA3Pg5G958Z jon@nixos-fleet
```

```
Host desktop      → 100.74.117.36
Host workstation  → 100.87.216.16
Host nas          → 100.95.201.10
Host laptop       → 100.104.109.104
Host portable     → portable (LAN/mDNS)
```

SSH host configs managed by Syncthing in `~/.ssh/config.d/`.

---

## DNS

All hosts run dnscrypt-proxy:
- **Upstream:** Cloudflare DoH (primary), Google DoH (backup)
- **DNSSEC:** Required
- **Tailscale MagicDNS:** Disabled (`--accept-dns=false`)

---

## Disko

Declarative disk layouts using stable `/dev/disk/by-id/` paths. Each host has a `disko.nix`.

```bash
# Format disks (DESTRUCTIVE — only during provisioning)
sudo disko --mode disko /path/to/disko.nix

# Mount only (non-destructive)
sudo disko --mode mount /path/to/disko.nix
```

The disko NixOS module generates `fileSystems`/`swapDevices` during `nixos-rebuild switch` — it does NOT reformat disks.

---

## Adding a New Host

1. Create `hosts/<name>/` with `default.nix`, `hardware.nix`, `disko.nix`
2. Add `nixosConfigurations.<name>` to `flake.nix`
3. Set unique `networking.hostName` and `networking.hostId`
   ```bash
   head -c 8 /dev/urandom | od -A none -t x4 | tr -d ' '
   ```
4. Add SSH authorized key
5. Add Syncthing device ID to `modules/services/syncthing.nix`
6. Boot portable → format with disko → `nixos-install --flake /tmp/dotfiles#<name> --no-root-passwd`

---

## Secrets

Managed with [agenix](https://github.com/ryantm/agenix). Encrypted with age, decrypted at activation.

| Secret | Used by |
|--------|---------|
| `password-jon.age` | All hosts — user password |
| `caddy-cloudflare-token.age` | NAS, Workstation — Caddy ACME DNS |
| `wifi-psk.age` | All hosts — WiFi passphrase |
| `openrouter-api-key.age` | NAS, Workstation — frontier API |
| `gateway-token.age` | NAS — orchestrator gateway |

---

## Flake Inputs

| Input | Purpose |
|-------|---------|
| `nixpkgs` | NixOS 25.11 packages |
| `nixpkgs-unstable` | Bleeding edge packages |
| `home-manager` | Per-user config (git, ssh, bash, vscode, direnv) |
| `disko` | Declarative disk partitioning |
| `agenix` | Age-encrypted secrets management |
| `claude-code` | Claude Code CLI |
| `nullclaw` | NullClaw binary package |
