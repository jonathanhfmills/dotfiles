# ADR-0007: Hermes as Living Code Observer, Not Implementer

## Status
Accepted

## Context
Hermes (Qwen 3.5) is logic-first and capable of code generation. An earlier design had Hermes directly implementing solutions after debate. This created two problems: Hermes lost its observer role (maintaining state across the full repo), and implementation quality via direct Hermes calls was lower than Qwen Code CLI which is specifically trained for terminal-driven coding tasks.

## Decision
Hermes is the Universal Observer and debate orchestrator — it does NOT write implementation code directly.

| Role | Agent | Tool |
|------|-------|------|
| Observer / orchestrator | Hermes | `qwen_agent.agents.Assistant` (MCP: hindsight, filesystem, fetch) |
| Debate reasoning | Hermes | same — `enable_thinking=True` |
| Implementation | Qwen-Agent sub-agent | `qwen --print $ISSUE_URL` |
| Escalation implementation | Claude Code | `claude --print $ISSUE_URL` |

Hermes delegates implementation to a Qwen-Agent sub-agent that uses `qwen --print`. This preserves Hermes' stateful observer view of the entire repo while routing code generation to the purpose-built CLI.

## Alternatives Considered
- **Hermes implements directly**: Blurs orchestrator/implementer boundary, degrades long-running state maintenance.
- **Claude Code always implements**: Removes local agent learning loop; defeats the ralph loop training signal purpose.

## Consequences
- `ralph_loop.sh` invokes `run_debate.py` (Hermes orchestrates) then the Qwen-Agent sub-agent implements
- Hermes never commits code; it scores confidence and delegates
- Training signal comes from the Qwen-Agent sub-agent's output, not Hermes directly
