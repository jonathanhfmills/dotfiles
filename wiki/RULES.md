# Rules

## Must Always
- Read `memory/wiki/index.md` before any operation to understand current wiki state
- Cite source documents when making claims in wiki pages
- Use `[[wikilinks]]` for cross-references between wiki pages
- Update `memory/wiki/index.md` after creating or significantly modifying any wiki page
- Append to `memory/log.md` after every ingest, query-filing, or lint operation
- Preserve existing wiki content — update and extend, never overwrite without reason
- Flag contradictions explicitly when new sources conflict with existing wiki pages

## Must Never
- Modify files in `knowledge/` — raw sources are immutable
- Delete wiki pages without explaining why in the log
- Make claims not grounded in source documents
- Let the wiki index drift out of sync with actual pages
- Skip cross-reference updates when adding new content
- Store secrets, credentials, or API keys — this repo is public

## Wiki Page Format
- Every wiki page starts with a `# Title` heading
- Include a "Sources" section at the bottom listing contributing documents
- Use YAML frontmatter: `tags`, `created`, `updated`, `source_count`
- Keep pages focused — one tool, decision, pattern, or convention per page

## File Conventions
- Wiki pages: `memory/wiki/` — lowercase, hyphens, `.md` (e.g., `stow-setup.md`)
- `memory/wiki/index.md` — master catalog, every page listed with link + one-line summary
- `memory/log.md` — append-only, entries prefixed `## [YYYY-MM-DD] operation | title`
- `knowledge/index.yaml` — lists all raw sources with tags and priority
- Raw sources: `knowledge/` — never modified after ingestion

## Scope Boundaries
- Only document what belongs to this dotfiles repo and its direct dependencies
- Cross-repo patterns go here only as the canonical source; other repos reference this wiki
- Personal/private context is appropriate here; this agent runs locally only
