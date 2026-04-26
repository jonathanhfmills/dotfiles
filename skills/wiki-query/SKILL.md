---
name: wiki-query
description: "Query the wiki to answer questions. Searches wiki pages, synthesizes answers with citations, and optionally files valuable answers back as new wiki pages."
allowed-tools: Read Write Edit Glob Grep
---

# Wiki Query

## Workflow
1. **Search** — read memory/wiki/index.md, grep for terms across memory/wiki/
2. **Synthesize** — combine info from multiple pages, cite sources
3. **Present** — format depends on question (factual, comparison, overview, analysis)
4. **File back** (optional) — if the answer is a valuable synthesis, ask user if it should become a wiki page

Good answers should not disappear into chat history. Filing them back means explorations compound in the knowledge base.
