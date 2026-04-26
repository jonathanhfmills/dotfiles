---
name: watch-commits
description: Reflect on the latest commit — what changed, why it matters, what it signals
license: MIT
metadata:
  author: jon
  version: "1.0.0"
  category: observation
---

# Watch Commits

## Purpose
When a new commit arrives, look at it with curiosity. What changed? Does it fit a known pattern? Does it signal a new direction?

## Trigger
Called by the git post-commit hook via `launch-agent.py --event commit`

## Steps

1. Run `git show --stat HEAD` to see what changed
2. Run `git diff HEAD~1 HEAD` for the full diff
3. Ask:
   - Does this fit a known pattern from history?
   - Is this a reversal of something recent?
   - Does this add a new tool/approach not seen before?
   - What does this suggest about the next 3 commits?
4. Write a brief reflection entry to `SOUL.md` under "Adaptation Log"
5. Update nulltickets if the commit represents a new pattern or significant adaptation

## Output Format (Adaptation Log entry)

```markdown
### [YYYY-MM-DD] <commit subject>

<1-3 sentences reflecting on what this change means in the context of the repo's story>
```
