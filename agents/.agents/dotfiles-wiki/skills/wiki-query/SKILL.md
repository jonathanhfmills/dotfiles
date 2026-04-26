# wiki-query

Answer a question using the wiki, and optionally file the answer back.

## Steps

1. Read `memory/wiki/index.md` to identify relevant pages
2. Read relevant wiki pages
3. Synthesize an answer with citations to wiki pages and source docs
4. If the answer is non-trivial and reusable:
   - Create or update a wiki page with the synthesized answer
   - Update `memory/wiki/index.md`
   - Append to `memory/log.md`: `## [YYYY-MM-DD] query-filed | <topic>`
5. If answer is already well-covered in wiki, return it with page references

## Output Format

- Lead with the answer
- Cite wiki pages: `[[page-name]]`
- Cite source docs: `knowledge/<filename>`
- Flag gaps: "⚠️ No wiki page covers X — consider ingesting a source"

## Notes
- Good answers get filed back as wiki pages — knowledge compounds
- Don't fabricate — if wiki doesn't cover it, say so and suggest ingestion
