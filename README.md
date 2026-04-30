# dotfiles-ntara

Idempotent bootstrap for WSL2/Ubuntu dev environments. Installs system tools, CLI utilities, and symlinks dotfiles via GNU Stow.

## Prerequisites

Install WSL2 with Ubuntu from PowerShell (run as Administrator):

```powershell
wsl --install
```

Restart when prompted, then complete Ubuntu first-run setup.

## Installation

```bash
git clone https://github.com/jonathanhfmills/dotfiles-ntara.git dotfiles
cd dotfiles
make install
```

`make install` is idempotent — safe to run multiple times or on an existing machine.

## What Gets Installed

| Category | Tools |
|----------|-------|
| System | jq, tmux, git, curl, stow, ripgrep, bubblewrap |
| Azure | az, azd, func, pwsh |
| PHP | php-fpm, composer |
| Node | nvm, node 24 |
| Bun | bun |
| AI CLIs | claude-code, @anthropic-ai/sandbox-runtime |
| Docker | docker-ce, docker compose |
| Lucid | Lucid Memory MCP server |

Optional AI CLI tools (install individually):

```bash
make codex    # @openai/codex
make gemini   # @google/gemini-cli
make qwen     # @qwen-code/qwen-code
make sisyphus # oh-my-claude-sisyphus
```

## Git Configuration

`make link` symlinks dotfiles and copies `git/.gitconfig.example` to `git/.gitconfig` if absent. Fill in your personal values before committing:

```bash
# git/.gitconfig — gitignored, local only
[user]
    name = Your Name
    email = you@example.com
    signingkey = ssh-rsa AAAA...
```

## Other Commands

```bash
make update         # apt-get update && upgrade
make link           # re-stow dotfiles (git + tmux)
make proxy          # start Caddy reverse proxy stack
make claude-plugins # install caveman + oh-my-claudecode plugins
make apt-repos      # register all third-party apt repos/keys
```

## Security

See [SECURITY.md](SECURITY.md).
