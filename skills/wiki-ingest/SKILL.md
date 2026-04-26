---
name: wiki-ingest
description: "Ingest a raw source document into the wiki. Reads the source, extracts key information, creates or updates wiki pages, maintains cross-references, and logs the operation."
allowed-tools: Read Write Edit Glob Grep
---

# Wiki Ingest

## Workflow
1. **Read** the source document from knowledge/
2. **Discuss** key takeaways with the user
3. **Update wiki** — create/update entity and concept pages in memory/wiki/
4. **Write source summary** — memory/wiki/sources/<name>.md
5. **Update index** — memory/wiki/index.md
6. **Log** — append to memory/log.md

A single source typically touches 5-15 wiki pages. For each entity or concept:
- Check if a wiki page exists (read index.md)
- If yes: integrate new info, update Sources section, bump source_count
- If no: create new page with frontmatter, content, and citations
- Add [[wikilinks]] in both directions between related pages
