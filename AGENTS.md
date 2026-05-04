<!-- Generated: 2026-04-28 | Updated: 2026-04-30 -->

# dotfiles

## Purpose
Personal dotfiles for WSL2/Ubuntu dev environment. Manages installation of system tools, CLI apps, and symlinks config files via GNU Stow.

## Key Files

| File | Description |
|------|-------------|
| `Makefile` | Idempotent installer — run `make install` on fresh machine |

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `git/` | git config stow package (see `git/AGENTS.md`) |
| `tmux/` | tmux config stow package (see `tmux/AGENTS.md`) |
| `.claude/` | Claude Code global config stow package (target: `~/.claude`, see `.claude/AGENTS.md`) |
| `.codex/` | Codex global config stow package (target: `~/.codex`) — `AGENTS.md` doubles as behavioral guidelines |
| `.gemini/` | Gemini CLI global config stow package (target: `~/.gemini`, see `.gemini/AGENTS.md`) |
| `.qwen/` | Qwen global config stow package (target: `~/.qwen`, see `.qwen/AGENTS.md`) |
| `proxy/` | Caddy reverse proxy Docker stack (see `proxy/AGENTS.md`) |
| `scripts/` | Utility shell scripts (empty, reserved) |

## Makefile Targets

| Target | Purpose |
|--------|---------|
| `install` | Core bootstrap: apt + gh + pwsh + nvm + node + claude + npm-globals + claude-plugins + docker + link. Excludes php, language runtimes, and all LSP targets (opt-in) |
| `update` | `apt-get update && upgrade` |
| `apt` | Base system packages + clangd (C/C++ LSP). Installs clangd-lsp plugin if `claude` present |
| `apt-repos` | Register all third-party apt repos/keys (gh, claude-code, docker) |
| `gh` | GitHub CLI (depends on `apt-repos`) |
| `php` | PHP-FPM + extensions + intelephense (PHP LSP). Installs php-lsp plugin if `claude` + `npm` present |
| `composer` | Composer (depends on `php`) |
| `pwsh` | PowerShell via packages-microsoft-prod.deb |
| `nvm` | Node Version Manager |
| `node` | Node.js via nvm + typescript-language-server + bash-language-server. Installs typescript-lsp + bash-language-server plugins |
| `bun` | Bun JavaScript runtime |
| `claude` | Claude Code CLI via apt (depends on `apt-repos`) |
| `npm-globals` | `@anthropic-ai/sandbox-runtime` (depends on `node`) |
| `omc` | `oh-my-claude-sisyphus` npm global (opt-in) |
| `codex` | `@openai/codex` npm global (opt-in) |
| `gemini` | `@google/gemini-cli` npm global (opt-in) |
| `qwen` | `@qwen-code/qwen-code` npm global (opt-in) |
| `claude-plugins` | Install caveman + oh-my-claudecode plugins |
| `docker` | Docker Engine + compose plugin (depends on `apt-repos`) |
| `lucid` | Lucid Memory MCP server (depends on `bun`) |
| `link` | Symlink stow packages → `$HOME` (tmux, git, .claude, .codex, .gemini, .qwen) |
| `proxy` | Start Caddy reverse proxy stack |
| `ssh` | openssh-server on port 2222, key auth only (opt-in; for Claude Desktop Remote SSH) |
| `go` | Go runtime + gopls LSP + gopls-lsp plugin (opt-in) |
| `rust` | Rust via rustup + rust-analyzer + rust-analyzer-lsp plugin (opt-in) |
| `dotnet` | .NET LTS + .NET 8 SDK + csharp-ls wrapper + csharp-lsp plugin (opt-in) |
| `java` | default-jdk + jdtls LSP + jdtls-lsp plugin (opt-in) |
| `python` | ty (Astral Python LSP) + pyright-lsp plugin (opt-in) |
| `lua` | lua-language-server + lua-lsp plugin (opt-in) |
| `lsp-servers` | Meta-target: runs node + go + rust + dotnet + java + python + lua (opt-in) |
| `claude-lsp-plugins` | Install all official LSP plugins without binaries — use individual language targets for full setup (opt-in) |

## For AI Agents

### Working In This Directory
- Makefile targets must be idempotent — check before install, skip if already present
- All targets listed in `.PHONY` and chained in `install:`
- Stow packages: each subdir mirrors `$HOME` layout
- Docker target uses `.list` format (not `.sources`) — avoids apt parse errors
- Python packages use `--break-system-packages` (Ubuntu 24+ externally-managed env)

### Adding a New Tool
1. Add idempotency-guarded target (`if ! command -v ...`)
2. Add to `.PHONY` and `install:` chain
3. If tool has dotfiles → create `toolname/` stow package, add to `link:` target

### Testing Requirements
- `make <target>` individually before wiring into `install:`
- Idempotency: run twice, second run must be no-op

### Common Patterns
- Idempotency: `@if ! command -v <tool> &>/dev/null; then ... else echo "already installed"; fi`
- Apt repo: GPG key → `.list` file → `apt-get update` → install
- Stow (home): `stow -d "$(CURDIR)" -t "$(HOME)" <package>`
- Stow (subdir target): `stow -d "$(CURDIR)" -t "$(HOME)/<subdir>" <package>` (e.g. `.claude` → `~/.claude`)

## Dependencies

### External
- `stow` — symlink management
- `apt-get` — package installation
- `curl` — downloading installers/GPG keys

<!-- MANUAL: -->
