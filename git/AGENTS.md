<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-28 | Updated: 2026-04-28 -->

# git

## Purpose
Stow package for git configuration. Files mirror `$HOME` layout — stow symlinks them into `~`.

## Key Files

| File | Description |
|------|-------------|
| `.gitconfig` | Global git config: credentials, user, GPG signing, SSH |

## For AI Agents

### Working In This Directory
- Layout must mirror `$HOME` exactly — `.gitconfig` here → `~/.gitconfig`
- Credential helpers use `gh auth git-credential` for github.com and gist.github.com
- Commits signed via SSH key; signing program is `op-ssh-sign-wsl.exe` (1Password, Windows-side)
- `core.sshCommand = ssh.exe` — uses Windows SSH agent through WSL interop
- Add new config files at same relative path they'd live under `$HOME`

### Testing Requirements
- `stow -d ~/dotfiles -t ~ git --simulate` — dry-run, confirm no conflicts
- `git config --list --show-origin` — verify symlinked config loads correctly

### Common Patterns
- Double `helper =` lines: first clears any system-level helper, second sets the new one

## Dependencies

### External
- `gh` — GitHub CLI, provides `gh auth git-credential`
- `op-ssh-sign-wsl.exe` — 1Password SSH signing agent (Windows)

<!-- MANUAL: -->
