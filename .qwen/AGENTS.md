<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-30 | Updated: 2026-04-30 -->

# .qwen

## Purpose
Stow package for Qwen Code global config. Files mirror `~/.qwen/` layout — stow symlinks them into `~/.qwen/`.

## Key Files

| File | Description |
|------|-------------|
| `QWEN.md` | Global behavioral guidelines for Qwen Code (sections 1-6) — stowed to `~/.qwen/QWEN.md` |

## For AI Agents

### Working In This Directory
- Stow target is `~/.qwen/`, not `$HOME` — use `stow -d ~/dotfiles -t ~/.qwen .qwen`
- `QWEN.md` content mirrors `.claude/CLAUDE.md` sections 1-6 (keep in sync manually)
- Layout mirrors `~/.qwen/` exactly

### Testing Requirements
- `stow -d ~/dotfiles -t ~/.qwen .qwen --simulate` — dry-run, confirm no conflicts
- Verify: `ls -la ~/.qwen/QWEN.md` should show symlink to `../dotfiles/.qwen/QWEN.md`

## Dependencies

### External
- `stow` — symlink management
- `@qwen-code/qwen-code` — reads `~/.qwen/QWEN.md` as global instructions

<!-- MANUAL: -->
