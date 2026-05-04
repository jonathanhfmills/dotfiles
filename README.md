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
| GitHub CLI | gh |
| PowerShell | pwsh |

Optional — install individually:

```bash
make php         # PHP-FPM + composer + intelephense (PHP LSP)
make claude      # Claude Code CLI
make codex       # @openai/codex
make gemini      # @google/gemini-cli
make qwen        # @qwen-code/qwen-code
make omc         # oh-my-claude-sisyphus
make lucid       # Lucid Memory MCP server (depends on bun)
```

## Language Runtimes + LSPs

Each language target installs the runtime, LSP binary, and Claude Code LSP plugin together:

```bash
make go      # Go + gopls + gopls-lsp plugin
make rust    # Rust + rust-analyzer + rust-analyzer-lsp plugin
make dotnet  # .NET (LTS + 8) + csharp-ls + csharp-lsp plugin
make java            # OpenJDK + jdtls + jdtls-lsp plugin
make python          # ty (Astral Python LSP) + pyright-lsp plugin
make lua             # lua-language-server + lua-lsp plugin
make lsp-servers     # all of the above at once
```

Claude Code LSP plugins are installed automatically when `claude` is in PATH. All LSP binaries land in `~/.local/bin` (already in PATH).

> **Note:** `kotlin-lsp` and `swift-lsp` plugins have no Linux binary available. Install manually if needed.

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
make update          # apt-get update && upgrade
make link            # re-stow dotfiles (git, tmux, .claude, .codex, .gemini, .qwen)
make proxy           # start Caddy reverse proxy stack
make claude-plugins  # install caveman + oh-my-claudecode plugins
make apt-repos       # register all third-party apt repos/keys
make bun             # Bun JavaScript runtime
make ssh             # openssh-server on port 2222 (Claude Desktop Remote SSH)
```

## Contributions

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Security

See [SECURITY.md](SECURITY.md).
