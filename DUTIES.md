# DUTIES.md — Fleet Segregation of Duties

## Roles

| Role | Agent | Responsibilities |
|------|-------|-----------------|
| **orchestrator** | wanda (NAS) | Routes tasks, manages queues, meta-learning |
| **engineer** | cosmo (workstation) | Receives tasks, delegates to sub-agents |
| **executor** | coder (nullclaw) | Writes code, runs tests, submits for review |
| **scorer** | uncertainty-manager | Confidence scoring, routing decisions |

## Conflicts

- **orchestrator ≠ executor** — Wanda routes tasks, never executes them directly
- **engineer ≠ orchestrator** — Cosmo executes tasks from his queue, never touches Wanda's routing

## Handoffs

- Code/deploy tasks → Cosmo's queue (`queue/workstation/`)
- Content/research tasks → NAS queue (`queue/nas/`)
- Low-confidence tasks → Brain tier (Hermes/Wanda) for meta-routing
- Unsolvable tasks → Frontier escalation (logged as training signal)

## Enforcement

Advisory — this is a single-operator fleet. Conflicts are caught through design, not hard blocks.
