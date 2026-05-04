# dotfiles

Idempotent bootstrap for WSL2/Ubuntu dev environments. Installs system tools, CLI utilities, and symlinks dotfiles via GNU Stow.

## Prerequisites

Install WSL2 with Ubuntu from PowerShell (run as Administrator):

```powershell
wsl --install
```

Restart when prompted, then complete Ubuntu first-run setup.

## Installation

```bash
git clone https://github.com/jonathanhfmills/dotfiles.git ~/dotfiles
sudo apt update && sudo apt install build-essential
cd ~/dotfiles && make install
```

`make install` is idempotent — safe to run multiple times or on an existing machine.

## What Gets Installed

`make install` installs only the essentials:

| Category | Tools |
|----------|-------|
| System | jq, tmux, git, curl, stow, ripgrep, bubblewrap, socat, unzip |
| Node | nvm, node 24, @anthropic-ai/sandbox-runtime |
| Docker | docker-ce, docker compose |
| Claude Code | claude CLI + caveman + oh-my-claudecode plugins |

## AI Tools

Claude Code is installed by default with caveman + oh-my-claudecode plugins, oh-my-claude-sisyphus (OMC), and Lucid Memory MCP server.

Other AI CLIs are opt-in:

```bash
make codex   # @openai/codex
make gemini  # @google/gemini-cli
make qwen    # @qwen-code/qwen-code
```

## Languages + LSPs

Each target installs the runtime, LSP binary, and Claude Code LSP plugin together:

```bash
make php     # PHP-FPM + composer + intelephense + php-lsp plugin
make go      # Go + gopls + gopls-lsp plugin
make rust    # Rust + rust-analyzer + rust-analyzer-lsp plugin
make csharp  # .NET (LTS + 8) + PowerShell + csharp-ls + csharp-lsp plugin
make java    # OpenJDK + jdtls + jdtls-lsp plugin
make python  # ty (Astral) + pyright-lsp plugin
make lua     # lua-language-server + lua-lsp plugin

make lsp-servers  # all of the above at once
```

LSP binaries land in `~/.local/bin` (already in PATH). Plugins install automatically when `claude` is in PATH.

> **Note:** `kotlin-lsp` and `swift-lsp` have no Linux binary. Install manually if needed.

## Other Commands

```bash
make update     # apt-get update && upgrade
make link       # re-stow dotfiles (git, tmux, .claude, .codex, .gemini, .qwen)
make proxy      # start Caddy reverse proxy stack
make apt-repos  # register third-party apt repos/keys (gh, claude-code, docker)
make gh         # GitHub CLI
make bun        # Bun JavaScript runtime
make ssh        # openssh-server on port 2222 (Claude Desktop Remote SSH)
make lucid      # Lucid Memory MCP (also auto-installed via make claude-plugins)
```

## Git Configuration

`make link` symlinks dotfiles and seeds global AI config. Also copies `git/.gitconfig.example` to `git/.gitconfig` if absent — fill in your personal values:

```bash
# git/.gitconfig — gitignored, local only
[user]
    name = Your Name
    email = you@example.com
    signingkey = ssh-rsa AAAA...
```

## Contributions

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Security

See [SECURITY.md](SECURITY.md).
