# wiki-lint

Audit wiki health and fix structural issues.

## Checks

1. **Index sync** — every page in `memory/wiki/` is listed in `index.md`, no dead entries
2. **Broken wikilinks** — `[[links]]` that reference non-existent pages
3. **Missing sources** — pages that cite `knowledge/` files that don't exist
4. **Stale pages** — pages not updated after related sources were re-ingested
5. **Oversized pages** — pages > 500 lines (candidate for splitting)
6. **Missing frontmatter** — pages without `tags`, `created`, `updated`
7. **Orphan pages** — pages with no inbound wikilinks

## Steps

1. Read `memory/wiki/index.md`
2. List all files in `memory/wiki/`
3. Run each check above
4. Report findings grouped by severity: `ERROR`, `WARN`, `INFO`
5. Fix `ERROR` items automatically (broken index entries, missing frontmatter)
6. Report `WARN` and `INFO` items for human review
7. Append to `memory/log.md`: `## [YYYY-MM-DD] lint | <N errors, M warnings>`

## Output Format

```
ERROR: index.md lists [[missing-page]] but file does not exist → removed
WARN: stow-setup.md has no inbound wikilinks (orphan)
INFO: gitagent-structure.md last updated 30+ days ago
```
