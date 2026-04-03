# Fleet Manifest — Ruflo-Core 5

**Total Agents: 5**

| Agent | Directory | Role | Model | Stateful |
|-------|-----------|------|-------|----------|
| **Wanda** | `agents/wanda/` | Planner / Orchestrator | Crow-9B (Wanda SGLang) | Yes |
| **Cosmo** | `agents/cosmo/` | Coder / Engineer | Crow-9B (Cosmo vLLM) | Yes |
| **Researcher** | `agents/cosmo/agents/researcher/` | Research & Analysis | NullClaw | Stateless |
| **Reviewer** | `agents/cosmo/agents/reviewer/` | Code Review | NullClaw | Stateless |
| **Tester** | `agents/cosmo/agents/tester/` | QA / Testing | NullClaw | Stateless |

## Architecture

```
User task
    ↓
Wanda (OpenClaw Planner, Crow-9B, Wanda SGLang)
    ├── gh issue create → branch: work/{n}-{slug}
    ├── Cosmo (implementation, TDD, PRs)
    │     ├── Researcher (analysis, dependency mapping)
    │     ├── Tester (unit/integration/E2E coverage)
    │     └── Reviewer (security, quality, performance)
    ├── NullClaw workers (scoped rapid tasks, ROCK sandboxes)
    └── Escalation: claude-code (GH issue URL) | gemini-cli (research)
         ↓
    gh pr create → Closes #{issue}
```

## RL Signal

GSPO training picks up trajectories from coder/reviewer/tester in `/var/lib/vllm/models/trajectories/`.
Focused fleet → cleaner signal → faster learning per task type.
