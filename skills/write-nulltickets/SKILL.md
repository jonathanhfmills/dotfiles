---
name: write-nulltickets
description: Write structured findings to nulltickets for cross-repo memory and orchestration
license: MIT
metadata:
  author: jon
  version: "1.0.0"
  category: memory
---

# Write Nulltickets

## Purpose
Structured, queryable memory. Other agents (openclaw orchestrator, other repo-agents) read nulltickets to understand this repo without reading SOUL.md from scratch.

## Namespace

All entries go under namespace: `dotfiles`

## Entry Types

| Type | When to write | Fields |
|------|--------------|--------|
| `pattern` | Recurring practice confirmed across 3+ commits | `name`, `description`, `first_seen`, `last_seen`, `confidence` |
| `anti-pattern` | Something repeatedly reverted or replaced | `name`, `description`, `evidence`, `replacement` |
| `adaptation` | Major pivot (tool swap, philosophy change) | `name`, `from`, `to`, `reason`, `date` |
| `prediction` | Agent's forecast about future direction | `name`, `rationale`, `confidence`, `created` |

## API

```bash
# Write a pattern
nulltickets create --namespace dotfiles --type pattern \
  --title "idempotent Makefile deps" \
  --body "All deps guarded with which/paru -Q. Added progressively across 3 sessions."

# Query patterns
nulltickets list --namespace dotfiles --type pattern
```

## Update vs Create

Before creating, check if an existing entry should be updated:
```bash
nulltickets list --namespace dotfiles --type pattern | grep "<name>"
```
