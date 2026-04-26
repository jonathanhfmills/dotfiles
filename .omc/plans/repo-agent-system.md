# Plan: Dotfiles Repo-Agent System

**Date:** 2026-04-26  
**Scope:** Wire the dotfiles repo as the first living repo-agent — self-aware, adaptive, composable.

---

## Requirements Summary

The dotfiles repo becomes a living agent that:
- Reads its own evolution (git history → patterns, adaptations)
- Responds to present changes (commits → reflection)
- Writes its findings as narrative (`SOUL.md`) and structured memory (nulltickets)
- Runs as a gitagent, executes via nullclaw inside an AIO sandbox workstation
- Registers in the gitagent registry for cross-repo composition

---

## Acceptance Criteria

- [ ] `gitagent run` on dotfiles repo launches the agent successfully
- [ ] Agent reads all commits in `git log` and writes initial pattern analysis to `SOUL.md`
- [ ] On each new commit, agent wakes and appends a reflection entry to `SOUL.md`
- [ ] Findings written to nulltickets under namespace `dotfiles`
- [ ] Agent registered in gitagent registry with adapters: `claude`, `nullclaw`
- [ ] AIO sandbox mounts `~/dotfiles` and `~/.nulltickets` as persistent volumes
- [ ] Cross-repo query: another agent can ask "what does dotfiles know about its own patterns?"

---

## Implementation Steps

### Phase 1 — Agent Identity (gitagent spec)

**1.1** Create `~/dotfiles/agent.yaml`:
```yaml
spec_version: "0.1.0"
name: dotfiles
version: 1.0.0
description: Living agent for the dotfiles repo — reads adaptation, watches evolution, writes its own story
author: jon
model:
  preferred: claude-sonnet-4-6
  fallback:
    - claude-haiku-4-5-20251001
  constraints:
    temperature: 0.3
    max_tokens: 8192
skills:
  - read-history
  - watch-commits
  - write-soul
  - write-nulltickets
  - compose
runtime:
  max_turns: 50
  timeout: 600
tags:
  - dotfiles
  - living-code
  - repo-agent
```

**1.2** Overwrite `~/dotfiles/SOUL.md` with repo-agent identity:
- Past: what has changed and why (adaptation story)
- Present: current state, active patterns
- Future: predicted evolution based on trajectory
- Keep the wiki-maintainer philosophy as a skill, not the core identity

**1.3** Create skills in `~/dotfiles/skills/`:
- `read-history/SKILL.md` — `git log --follow`, extract patterns/anti-patterns
- `watch-commits/SKILL.md` — diff latest commit, reflect on change
- `write-soul/SKILL.md` — append narrative entry to SOUL.md
- `write-nulltickets/SKILL.md` — write structured findings to nulltickets API
- `compose/SKILL.md` — respond to cross-repo queries from other agents

---

### Phase 2 — Runtime (nullclaw + AIO sandbox)

**2.1** Update `~/dotfiles/opensandbox/.sandbox.toml`:
```toml
[storage]
allowed_host_paths = [
  "/home/jon/dotfiles",
  "/home/jon/.nulltickets"
]

[renew_intent]
enabled = true
min_interval_seconds = 60
```

**2.2** Create `~/dotfiles/opensandbox/launch-agent.py`:
- Uses `opensandbox` SDK to create AIO sandbox
- Mounts `~/dotfiles` as workstation root
- Starts nullclaw gateway inside sandbox
- Passes `agent.yaml` to nullclaw on launch

**2.3** nullclaw config at `~/.nullclaw/config.json`:
- Add `dotfiles` agent profile with system prompt derived from `SOUL.md`
- Model: `ollama/qwen3.5:9b-q8_0` (local) or `claude-sonnet-4-6` (cloud)

---

### Phase 3 — Event Wiring

**3.1** Git post-commit hook at `~/dotfiles/.git/hooks/post-commit`:
```bash
#!/bin/bash
# Wake the dotfiles agent on commit
python3 ~/dotfiles/opensandbox/launch-agent.py --event commit &
```

**3.2** Initial history run (one-time bootstrap):
```bash
python3 ~/dotfiles/opensandbox/launch-agent.py --event bootstrap
```
Agent reads all commits, writes initial SOUL.md + nulltickets entries.

---

### Phase 4 — Memory (nulltickets)

**4.1** Start nulltickets:
```bash
nulltickets serve --data ~/.nulltickets
```
Add to Makefile as a service.

**4.2** nulltickets namespace `dotfiles`:
- `patterns` — recurring code patterns observed
- `anti-patterns` — things that keep getting reverted/changed
- `adaptations` — major pivots (e.g., nullhub → nullclaw switch)
- `predictions` — what the agent thinks will happen next

---

### Phase 5 — Registration

**5.1** Register in gitagent registry:
```bash
gitagent registry -r https://github.com/jonathanhfmills/dotfiles -c personal -a claude,nullclaw
```

**5.2** Test cross-repo query from gitagent-architect:
```
"ask dotfiles: what are your top 3 anti-patterns?"
```

---

## Risks and Mitigations

| Risk | Mitigation |
|------|-----------|
| opensandbox-server not running | Add to systemd user service; Makefile starts it |
| nulltickets not running | Same — user service |
| AIO sandbox timeout during long history read | Set `timeout=86400` for bootstrap run |
| SOUL.md grows unbounded | Agent summarizes past entries monthly, archives to `memory/soul-archive/` |
| Local ollama model too slow for analysis | Fallback to claude-sonnet-4-6 via API |

---

## Verification Steps

1. `gitagent validate ~/dotfiles` — passes with no errors
2. `python3 ~/dotfiles/opensandbox/launch-agent.py --event bootstrap` — completes, SOUL.md updated
3. Make a commit → SOUL.md gets new entry within 60s
4. `nulltickets query --namespace dotfiles --type pattern` — returns results
5. From another gitagent context: ask dotfiles agent a question, get answer from its memory

---

## ADR

**Decision:** GitAgent spec + nullclaw runtime + AIO sandbox + nulltickets

**Drivers:**
1. Repo identity must travel with the code (agent.yaml + SOUL.md in repo)
2. Memory must persist across sandbox lifetimes (nulltickets external store)
3. Composable with future repo-agents (gitagent registry)

**Alternatives considered:**
- Claude Code hooks only — no persistent identity, no cross-repo composition
- nullhub managed instance — CLI too incomplete, health check broken

**Why chosen:** GitAgent gives identity + composability. nullclaw gives local execution. AIO sandbox gives isolated workstation with shared filesystem.

**Consequences:** Requires opensandbox-server + nulltickets running as local services. Adds `agent.yaml` to repo root.

**Follow-ups:**
- Add nullboiler workflow for scheduled (not just commit-triggered) analysis
- Add openclaw orchestrator for cross-repo synthesis once 3+ repo-agents exist
- Explore `rl-training` opensandbox example for agent self-improvement loop
