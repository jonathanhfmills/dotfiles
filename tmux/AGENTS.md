<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-27 | Updated: 2026-04-27 -->

# tmux

## Purpose
Stow package for tmux configuration. Files here mirror `$HOME` layout — stow symlinks them into `~`.

## Key Files

| File | Description |
|------|-------------|
| `.tmux.conf` | tmux configuration (keybinds, appearance, behaviour) |

## For AI Agents

### Working In This Directory
- Layout must mirror `$HOME` exactly — `.tmux.conf` here → `~/.tmux.conf`
- After editing `.tmux.conf`, reload with `tmux source ~/.tmux.conf` (no restart needed)
- Add new config files at same relative path they'd live under `$HOME`

### Testing Requirements
- `stow -d ~/dotfiles -t ~ tmux --simulate` — dry-run stow, confirm no conflicts
- `tmux source ~/.tmux.conf` — verify no syntax errors

<!-- MANUAL: -->
