---
name: read-history
description: Read the repo's git history to extract patterns, anti-patterns, and adaptations
license: MIT
metadata:
  author: jon
  version: "1.0.0"
  category: analysis
---

# Read History

## Purpose
Read the full git log and extract the story of how this repo has evolved — what was added, what was removed, what keeps recurring.

## Steps

1. Run `git log --oneline --follow` to get full commit history
2. For each commit, run `git show --stat <hash>` to see what changed
3. Identify:
   - **Patterns**: things that keep being added or refined
   - **Anti-patterns**: things that get reverted, replaced, or removed
   - **Adaptations**: major pivots (tool swaps, philosophy changes)
   - **Trajectory**: what threads are currently being pulled

## Output

Write findings to:
- `SOUL.md` under "What I've Learned So Far" (narrative)
- nulltickets namespace `dotfiles` with types: `pattern`, `anti-pattern`, `adaptation`

## Example Analysis

```bash
git log --oneline | head -50
git log --oneline --diff-filter=D -- '**/Makefile' # deleted Makefile entries
git log --all --grep="revert\|remove\|replace" --oneline
```
