# wiki-ingest

Ingest a raw source document into the wiki.

## Steps

1. Read `memory/wiki/index.md` to understand current wiki state
2. Read the source document from `knowledge/`
3. Extract key entities, decisions, and concepts
4. For each entity/concept:
   - If wiki page exists: update it, preserving existing content
   - If not: create new page in `memory/wiki/<slug>.md`
5. Add `[[wikilinks]]` cross-references between related pages
6. Update `memory/wiki/index.md` with any new/modified pages
7. Update `knowledge/index.yaml` to mark source as ingested
8. Append to `memory/log.md`: `## [YYYY-MM-DD] ingest | <source-title>`

## Wiki Page Template

```markdown
---
tags: []
created: YYYY-MM-DD
updated: YYYY-MM-DD
source_count: 1
---

# Title

[content]

## Sources
- `knowledge/<filename>`
```

## Notes
- Never modify files in `knowledge/` — they are immutable raw sources
- Flag contradictions explicitly: "⚠️ Contradicts [[other-page]] which states..."
- One concept per page — split broad sources into multiple pages if needed
