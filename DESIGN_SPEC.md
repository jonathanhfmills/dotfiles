# DESIGN_SPEC.md — dotfiles ADK Agent

## Overview
A2A-compatible ADK agent that orchestrates dotfiles operations via Gemini. Exposes stow deployment, wiki management, and agent lifecycle as callable A2A tools — allowing OMC and other agents to programmatically manage the dotfiles environment.

## Example Use Cases
- OMC calls `deploy_stow` to set up dotfiles on a new machine
- External agent calls `query_wiki` to retrieve dotfiles configuration knowledge
- gitagent calls `list_agents` to discover available global agents

## Tools Required
- `deploy_stow(packages: list[str])` — run stow for specified packages
- `query_wiki(query: str)` — delegate to wiki/ gitagent, return answer
- `list_agents()` — list all agents in ~/.agents/
- `get_agent_info(name: str)` — return agent.yaml for a named agent

## Constraints & Safety Rules
- Read-only operations by default; stow deploy requires explicit confirmation
- Never expose credentials or file contents outside ~/.agents/ and ~/dotfiles/
- No internet access required — all operations are local filesystem

## Success Criteria
- Agent responds correctly to A2A tool calls from external agents
- `deploy_stow` correctly runs stow and reports symlink status
- `query_wiki` returns answers grounded in wiki memory
- `list_agents` returns accurate agent inventory

## Reference Samples
None matched — this is a local filesystem orchestration agent.
