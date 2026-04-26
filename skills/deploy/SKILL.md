# deploy

Stow all packages and verify symlinks.

## Steps

1. Check current stow state: `ls ~/dotfiles/` for top-level package dirs (exclude `wiki/`, `skills/`, `memory/`, dot-files)
2. For each package dir: `stow -R <package> --dir ~/dotfiles --target ~`
3. Verify each stow target: `ls -la ~/.agents/` etc.
4. Report: packages deployed, symlinks verified, any errors

## Current Packages
- `agents/` → `~/.agents/`, `~/.local/bin/`

## New Machine Setup
```bash
cd ~/dotfiles
git clone https://github.com/jonathanhfmills/dotfiles .
sudo pacman -S stow python-yaml
stow agents
```
