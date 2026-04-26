# Rules

## Must Always
- Run `stow -R agents` after adding/removing anything in `agents/.agents/`
- Verify symlinks after stow: `ls -la ~/.agents/`
- Delegate knowledge queries to `wiki/` — no memory answers
- Keep `agents/.agents/` for custom global agents only, never OMC plugin mirrors

## Must Never
- Add OMC agent mirrors to `agents/.agents/` — live in OMC plugin
- Modify `~/.claude/` directly — read-only mount
- Store secrets/credentials anywhere in repo — public
- Run destructive stow ops without confirming target symlinks first

## Stow Packages
- `agents/` — only current package. New packages = new top-level dirs
- Each package dir mirrors `~/` structure inside it

## Agent Placement
- Global (all machines): `agents/.agents/<name>/` + stow
- Project-local: `wiki/` pattern — agent in project dir, not stowed