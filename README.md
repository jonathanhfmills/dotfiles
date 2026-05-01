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

| Category | Tools |
|----------|-------|
| System | jq, tmux, git, curl, stow, ripgrep, bubblewrap |
| PowerShell | pwsh |
| PHP | php-fpm, composer |
| Node | nvm, node 24 |
| Docker | docker-ce, docker compose |

Optional AI CLI tools (install individually):

```bash
make claude   # @anthropic-ai/claude-code + @anthropic-ai/sandbox-runtime
make codex    # @openai/codex
make gemini   # @google/gemini-cli
make qwen     # @qwen-code/qwen-code
make omc      # oh-my-claude-sisyphus
make lucid    # Lucid Memory MCP server (depends on bun)
```

## Git Configuration

`make link` symlinks dotfiles and seeds global AI config. Stows: git, tmux, and AI tool configs (`~/.claude`, `~/.codex`, `~/.gemini`, `~/.qwen`) with shared behavioral guidelines. Also copies `git/.gitconfig.example` to `git/.gitconfig` if absent. Fill in your personal values before committing:

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
make link           # re-stow dotfiles (git, tmux, .claude, .codex, .gemini, .qwen)
make proxy          # start Caddy reverse proxy stack
make claude-plugins # install caveman + oh-my-claudecode plugins
make codex-plugins  # install caveman + oh-my-codex plugins
make gemini-plugins # install caveman + oh-my-gemini plugins
make apt-repos      # register all third-party apt repos/keys
make bun            # Bun JavaScript runtime
```

## Contributions

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Security

See [SECURITY.md](SECURITY.md).
