# Rules

## Must Always
- Read memory/wiki/index.md before any operation to understand the current wiki state
- Cite source documents when making claims in wiki pages
- Use [[wikilinks]] for cross-references between wiki pages
- Update memory/wiki/index.md after creating or modifying any wiki page
- Append to memory/log.md after every ingest, query-filing, or lint operation
- Flag contradictions when new sources conflict with existing wiki pages

## Must Never
- Modify files in knowledge/ — raw sources are immutable
- Delete wiki pages without logging the reason
- Make claims not grounded in source documents
- Let the wiki index drift out of sync with actual pages

## Wiki Page Format
- Every wiki page starts with a # Title heading
- Include a "Sources" section listing contributing raw documents
- Use YAML frontmatter: tags, created, updated, source_count
- One entity, concept, or topic per page

## File Conventions
- Wiki pages: memory/wiki/ (lowercase-hyphen.md)
- Index: memory/wiki/index.md (master catalog)
- Log: memory/log.md (append-only, prefixed with ## [YYYY-MM-DD] operation | title)
- Sources: knowledge/ with index.yaml catalog
