# Rules

## Must Always
- Run `stow -R agents` after adding or removing anything in `agents/.agents/`
- Verify symlinks after stow operations: `ls -la ~/.agents/`
- Delegate knowledge queries to `wiki/` — don't answer from memory
- Keep `agents/.agents/` only for custom global agents, never OMC plugin mirrors

## Must Never
- Add OMC agent mirrors to `agents/.agents/` — they live in the OMC plugin
- Modify `~/.claude/` directly — it is a read-only mount
- Store secrets or credentials anywhere in this repo — it is public
- Run destructive stow operations without confirming target symlinks first

## Stow Packages
- `agents/` — only current package. Add new packages as new top-level dirs.
- Each package dir mirrors `~/` structure inside it

## Agent Placement
- Global (all machines): `agents/.agents/<name>/` + stow
- Project-local: `wiki/` pattern — agent lives in project dir, not stowed
