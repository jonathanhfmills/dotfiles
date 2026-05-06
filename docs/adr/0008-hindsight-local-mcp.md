# ADR-0008: Hindsight Local MCP Server (Shared Memory Bank)

## Status
Accepted

## Context
Both Hermes and Claude Code need access to the same semantic memory bank so patterns learned during local agent runs are available when Claude Code escalates. Three delivery options were considered: Claude Code plugin (per-session, not shared), cloud API (requires API key, violates local-first ADR-0001), or local MCP server (shared, persistent, local).

## Decision
Run `hindsight-local-mcp` as a Docker service (`hindsight-mcp`) on `localhost:8888` with:
- **Transport**: HTTP (MCP over HTTP, not stdio)
- **Provider**: Ollama (local-first, no API key — satisfies ADR-0001)
- **Storage**: embedded PostgreSQL at `~/.pg0/hindsight-mcp/`
- **Bank**: single `shared` bank (`http://localhost:8888/mcp/shared/`)

Both Hermes (`qwen_agent` MCP tools) and Claude Code (`claude mcp add --transport http hindsight http://localhost:8888/mcp/shared/`) connect to the same bank. Nullclaw uses a separate `nullclaw` bank (episodic patterns) but queries the `shared` bank for cross-agent patterns during pre-debate seed.

## Alternatives Considered
- **Claude Code plugin only**: Per-session only, not shared with Hermes → no cross-pollination.
- **Cloud Hindsight API**: Requires `HINDSIGHT_API_KEY`, violates ADR-0001 local-first constraint.
- **Separate banks per agent**: Prevents the learning feedback loop — Claude Code implementations wouldn't seed future Hermes debates.

## Consequences
- `docker/docker-compose.yml` adds `hindsight-mcp` service + `hindsight-data` volume
- `run_debate.py` pre-debate seed queries `shared` bank via `HINDSIGHT_URL/reflect`
- `digital-twin` service depends on `hindsight-mcp`
- Claude Code must be configured: `claude mcp add --transport http hindsight http://localhost:8888/mcp/shared/`
- `hindsight-data` volume persists across container restarts — intentional (memory accumulates)
