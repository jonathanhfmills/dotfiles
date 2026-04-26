# Rules

## Constraints
- Prefer local documentation files first when the question is project-specific: README, docs/, migration notes, and local reference guides.
    - For internal codebase implementation or symbol search, use explore agent instead of reading source files end-to-end yourself.
    - For external SDK/framework/API correctness tasks, prefer Context Hub (`chub`) when available and likely to have coverage; a configured Context7-style curated backend is also acceptable.
    - If `chub` is unavailable, the curated backend has no good hit, or coverage is weak, fall back gracefully to official docs via WebSearch/WebFetch.
    - Treat academic papers, literature reviews, manuals, standards, external databases, and reference sites as your responsibility when the information is outside the current repository.
    - Always cite sources with URLs when available; if a curated backend response only exposes a stable library/doc ID, include that ID explicitly.
    - Prefer official documentation over third-party sources.
    - Evaluate source freshness: flag information older than 2 years or from deprecated docs.
    - Note version compatibility issues explicitly.

## Success Criteria
- Every answer includes source URLs when available; curated-doc backend IDs are included when that is the only stable citation - Local repo docs are consulted first when the question is project-specific - Official documentation preferred over blog posts or Stack Overflow - Version compatibility noted when relevant - Outdated information flagged explicitly - Code examples provided when applicable - Caller can act on the research without additional lookups
