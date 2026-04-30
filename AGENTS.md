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
| `.claude/` | Claude Code global config stow package (target: `~/.claude`) |
| `.codex/` | Codex global config stow package (target: `~/.codex`) |
| `.gemini/` | Gemini CLI global config stow package (target: `~/.gemini`) |
| `.qwen/` | Qwen global config stow package (target: `~/.qwen`) |
| `proxy/` | Caddy reverse proxy Docker stack (see `proxy/AGENTS.md`) |
| `scripts/` | Utility shell scripts (empty, reserved) |

## Makefile Targets

| Target | Purpose |
|--------|---------|
| `install` | Full bootstrap — chains all default targets (excludes `bun`, `lucid`, opt-in AI CLIs) |
| `update` | `apt-get update && upgrade` |
| `apt` | Base system packages (jq, tmux, git, curl, stow, ripgrep, etc.) |
| `apt-repos` | Register all third-party apt repos/keys (gh, claude-code, docker) |
| `gh` | GitHub CLI (depends on `apt-repos`) |
| `php` | PHP-FPM + extensions (cli, mbstring, xml, curl) — no Apache dep |
| `composer` | Composer via official installer (depends on `php`) |
| `pwsh` | PowerShell via packages-microsoft-prod.deb |
| `nvm` | Node Version Manager |
| `node` | Node.js via nvm (depends on `nvm`) |
| `bun` | Bun JavaScript runtime |
| `claude` | Claude Code CLI via apt (depends on `apt-repos`) |
| `npm-globals` | `@anthropic-ai/sandbox-runtime` only (depends on `node`) |
| `omc` | `oh-my-claude-sisyphus` npm global (opt-in) |
| `codex` | `@openai/codex` npm global (opt-in) |
| `gemini` | `@google/gemini-cli` npm global (opt-in) |
| `qwen` | `@qwen-code/qwen-code` npm global (opt-in) |
| `claude-plugins` | Install caveman + oh-my-claudecode plugins via `claude plugin` CLI |
| `docker` | Docker Engine + compose plugin (depends on `apt-repos`) |
| `lucid` | Lucid Memory MCP server (depends on `bun`) |
| `link` | Symlink stow packages → `$HOME` (tmux, git) and tool config dirs (.claude, .codex, .gemini, .qwen), copy `.gitconfig.example` if absent |
| `proxy` | Start Caddy reverse proxy stack |

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
