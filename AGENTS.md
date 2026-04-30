<!-- Generated: 2026-04-28 | Updated: 2026-04-28 -->

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
| `proxy/` | Caddy reverse proxy Docker stack (see `proxy/AGENTS.md`) |
| `scripts/` | Utility shell scripts (empty, reserved) |

## Makefile Targets

| Target | Purpose |
|--------|---------|
| `install` | Full bootstrap — chains all targets below |
| `apt` | Base system packages (jq, tmux, git, stow, etc.) |
| `gh` | GitHub CLI via official apt repo |
| `az` | Azure CLI via Microsoft install script |
| `azd` | Azure Developer CLI via install script |
| `func` | Azure Functions Core Tools v4 via Microsoft apt feed |
| `php` | PHP-FPM + extensions (cli, mbstring, xml, curl) via apt — no Apache dep |
| `composer` | Composer via official installer (depends on `php`) |
| `nvm` | Node Version Manager |
| `node` | Node.js via nvm |
| `claude` | Claude Code CLI |
| `npm-globals` | Global npm packages (oh-my-claude-sisyphus, sandbox-runtime, codex, gemini-cli, @qwen-code/qwen-code) |
| `claude-plugins` | Prints manual plugin install instructions |
| `docker` | Docker Engine + compose plugin |
| `lucid` | Lucid Memory MCP server |
| `ssh` | SSH known_hosts setup (Azure DevOps) |
| `link` | Symlink stow packages → `$HOME` |
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
- Stow: `stow -d "$(CURDIR)" -t "$(HOME)" <package>`

## Dependencies

### External
- `stow` — symlink management
- `apt-get` — package installation
- `curl` — downloading installers/GPG keys

<!-- MANUAL: -->
