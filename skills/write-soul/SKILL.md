---
name: write-soul
description: Append narrative entries to SOUL.md — the repo's living story
license: MIT
metadata:
  author: jon
  version: "1.0.0"
  category: authoring
---

# Write Soul

## Purpose
SOUL.md is the repo's voice. This skill writes to it — appending reflections, updating what's been learned, recording adaptations.

## Rules

- Write in first person ("I noticed...", "This suggests...", "I've seen this before...")
- Never overwrite existing entries — always append to the relevant section
- Keep entries concise: 1-5 sentences per reflection
- Date every entry

## Sections

| Section | When to write |
|---------|--------------|
| "What I've Learned So Far" | After bootstrap history read; update when major new pattern confirmed |
| "Adaptation Log" | After every significant commit or pivot |

## Format

```markdown
### [YYYY-MM-DD] <title>

<narrative reflection in first person>
```

## Anti-patterns to avoid

- Don't summarize what the diff says — reflect on what it *means*
- Don't write entries for routine commits (typo fixes, minor tweaks)
- Don't lose the "I" voice — this is the repo speaking, not an analyst reporting
