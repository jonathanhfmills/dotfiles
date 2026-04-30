<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-30 | Updated: 2026-04-30 -->

# .gemini

## Purpose
Stow package for Gemini CLI global config. Files mirror `~/.gemini/` layout — stow symlinks them into `~/.gemini/`.

## Key Files

| File | Description |
|------|-------------|
| `GEMINI.md` | Global behavioral guidelines for Gemini CLI (sections 1-6) — stowed to `~/.gemini/GEMINI.md` |

## For AI Agents

### Working In This Directory
- Stow target is `~/.gemini/`, not `$HOME` — use `stow -d ~/dotfiles -t ~/.gemini .gemini`
- `GEMINI.md` content mirrors `.claude/CLAUDE.md` sections 1-6 (keep in sync manually)
- Layout mirrors `~/.gemini/` exactly

### Testing Requirements
- `stow -d ~/dotfiles -t ~/.gemini .gemini --simulate` — dry-run, confirm no conflicts
- Verify: `ls -la ~/.gemini/GEMINI.md` should show symlink to `../dotfiles/.gemini/GEMINI.md`

## Dependencies

### External
- `stow` — symlink management
- `@google/gemini-cli` — reads `~/.gemini/GEMINI.md` as global instructions

<!-- MANUAL: -->
