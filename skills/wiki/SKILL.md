# wiki

Delegate knowledge operations to the project wiki agent.

## Steps

1. Determine operation: ingest, query, or lint
2. Run wiki agent:
   ```bash
   npx @open-gitagent/gitagent@latest run -d ./wiki -a claude -p "<operation>"
   ```
3. Return result to user

## Operations
- **ingest**: "Ingest <source-file> into the wiki"
- **query**: "What does the wiki say about <topic>?"
- **lint**: "Run wiki-lint to check wiki health"

## Notes
- Wiki agent uses haiku model — lightweight, fast
- Sources go in `wiki/knowledge/` before ingesting
- Wiki pages live in `wiki/memory/wiki/`
