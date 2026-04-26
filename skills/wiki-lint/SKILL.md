---
name: wiki-lint
description: "Health-check the wiki for contradictions, stale claims, orphan pages, missing cross-references, and knowledge gaps."
allowed-tools: Read Glob Grep
---

# Wiki Lint

## Checks
- **Contradictions** — conflicting claims across pages
- **Stale claims** — pages not updated after newer sources arrived
- **Orphan pages** — no inbound [[wikilinks]]
- **Missing pages** — [[wikilinks]] pointing to nonexistent pages
- **Missing cross-references** — pages discussing same topic without linking
- **Knowledge gaps** — suggest questions and sources to investigate

## Output
Structured health report with counts and specific findings per category. Append summary to memory/log.md.
