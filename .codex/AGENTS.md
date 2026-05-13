<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-05-12 | Updated: 2026-05-12 -->

# .codex

## Purpose
Stow package for Codex global config. Files mirror `~/.codex/` layout — stow symlinks them into `~/.codex/`. The `AGENTS.md` file doubles as behavioral guidelines injected by Codex on startup.

## Key Files

| File | Description |
|------|-------------|
| `AGENTS.md` | Global behavioral guidelines for Codex — stowed to `~/.codex/AGENTS.md`; Codex reads this as agent instructions |

## For AI Agents

### Working In This Directory
- Stow target is `~/.codex/`, not `$HOME` — use `stow -d ~/dotfiles -t ~/.codex .codex`
- `AGENTS.md` content is the Karpathy coding guidelines (sections 1-7) — keep in sync with `.claude/CLAUDE.md` sections 1-7
- Layout mirrors `~/.codex/` exactly

### Testing Requirements
- `stow -d ~/dotfiles -t ~/.codex .codex --simulate` — dry-run, confirm no conflicts
- Verify: `ls -la ~/.codex/AGENTS.md` should show symlink to `../dotfiles/.codex/AGENTS.md`

## Dependencies

### External
- `stow` — symlink management
- `@openai/codex` — reads `~/.codex/AGENTS.md` as global instructions

<!-- MANUAL: -->
