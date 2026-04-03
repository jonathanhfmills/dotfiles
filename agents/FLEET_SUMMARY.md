# Fleet Summary — Ruflo-Core 5

## Architecture

```
User task
    ↓
Wanda (Planner, Crow-9B, NAS SGLang)
    ├── plan → YAML task decomposition
    ├── gh issue create per subtask
    ├── spawn NullClaw workers in ROCK sandboxes
    │
    ├── Cosmo (Coder/Engineer, Crow-9B, Workstation vLLM)
    │     writes code, tests, PRs
    │     ├── Researcher (stateless, YAML findings)
    │     ├── Tester (stateless, FIRST principles)
    │     └── Reviewer (stateless, structured reports)
    │
    ├── escalate → claude-code {gh_issue_url}
    └── escalate → gemini-cli (deep research)
         ↓
    gh pr create → "Closes #{issue}"
```

## Agents

| Agent | Role | Model | Notes |
|-------|------|-------|-------|
| **wanda** | Planner | Crow-9B / SGLang | Orchestrates, never codes |
| **cosmo** | Coder | Crow-9B / vLLM | TDD, SOLID/DRY/KISS |
| **researcher** | Analysis | NullClaw | Stateless, YAML findings — `agents/cosmo/agents/researcher/` |
| **reviewer** | Audit | NullClaw | Stateless, structured reports — `agents/cosmo/agents/reviewer/` |
| **tester** | QA | NullClaw | Stateless, FIRST principles — `agents/cosmo/agents/tester/` |

## RL Training

GSPO nightly training targets `coder`, `reviewer`, `tester` trajectories.
5 focused roles → cleaner reward signal → faster convergence.
