# ADR-0009: Extract Debate Engine to bicameral-mind Submodule

## Status
Accepted

## Context
The debate engine (scripts, docker stack, LogicAgent config) lived inside the dotfiles repo alongside the host agent (nullclaw). This coupling meant every repo that wanted bicameral debate would need to copy the engine. The engine evolves independently from host-repo agent personas.

## Decision
Extract the engine to `jonathanhfmills/bicameral-mind` and integrate as a git submodule.

| Concern | Location |
|---------|----------|
| Engine (scripts, docker, LogicAgent) | `bicameral-mind/` submodule |
| Host agent persona (nullclaw) | `agents/nullclaw/` in this repo |
| Training debate records | `debates/` in this repo |
| Makefile orchestration | Delegation targets: `make -C bicameral-mind <target> HOST_DIR=$(CURDIR)` |

Hermes is renamed to **LogicAgent** — a generic logic-first debater, not tied to this repo. `HERMES_LLAMA_URL`/`HERMES_MODEL` env vars still accepted as fallbacks for backwards compatibility.

## Alternatives Considered
- **Keep engine in dotfiles**: Every future repo would copy-paste the engine. Updates don't propagate.
- **Separate workflow, no submodule**: Loses the ability to pin engine version per host repo.

## Consequences
- `make debate` / `make ralph` / etc. delegate to `bicameral-mind` submodule
- New `make maintainer` target for openclaw observer (OpenClaw replaced Hermes as orchestration layer)
- `agents/hermes/` removed; `bicameral-mind/agents/logicagent/` is canonical logic agent
- Engine tests live in `bicameral-mind/tests/`; dotfiles tests cover submodule linkage and delegation
- To update engine: `cd bicameral-mind && git pull && cd .. && git add bicameral-mind && git commit`
- Submodule URL is currently local (`/home/jon/bicameral-mind`) — push to GitHub and run `git submodule set-url bicameral-mind https://github.com/jonathanhfmills/bicameral-mind` to finalize
