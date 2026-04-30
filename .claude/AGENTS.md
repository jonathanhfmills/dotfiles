<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-30 | Updated: 2026-04-30 -->

# .claude

## Purpose
Stow package for Claude Code global config. Files mirror `~/.claude/` layout — stow symlinks them into `~/.claude/`.

## Key Files

| File | Description |
|------|-------------|
| `CLAUDE.md` | Global behavioral guidelines for Claude (Karpathy rules + OMC config) — stowed to `~/.claude/CLAUDE.md` |

## For AI Agents

### Working In This Directory
- Stow target is `~/.claude/`, not `$HOME` — use `stow -d ~/dotfiles -t ~/.claude .claude`
- `CLAUDE.md` contains two sections: Karpathy guidelines (sections 1-6) above `<!-- OMC:START -->`, OMC config between markers
- OMC auto-manages content between `<!-- OMC:START -->` and `<!-- OMC:END -->` — do not edit that block manually
- Edit sections 1-6 freely; OMC block is overwritten on `omc update`
- `settings.local.json` and `CLAUDE.original.md` are gitignored — local only

### Testing Requirements
- `stow -d ~/dotfiles -t ~/.claude .claude --simulate` — dry-run, confirm no conflicts
- Verify: `ls -la ~/.claude/CLAUDE.md` should show symlink to `../dotfiles/.claude/CLAUDE.md`

## Dependencies

### External
- `stow` — symlink management
- `oh-my-claudecode` — manages OMC block in `CLAUDE.md`

<!-- MANUAL: -->
