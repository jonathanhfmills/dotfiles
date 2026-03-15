# Agent Infrastructure: Brain / Engineer / Grunt

## Overview

Three-tier agent architecture where each tier plays to its strengths. The system is a self-improving Claude Code competitor that learns from every task.

| Role | Agent | Host/Identity | What it does |
|------|-------|---------------|-------------|
| **Brain** | Hermes Agent | Wanda (NAS) | Routes tasks, learns patterns, self-improves via Atropos RL + GEPA |
| **Engineer** | Qwen-Agent | Cosmo (Workstation) | Native ATIC tool calling for Qwen3.5, MCP tools, code execution |
| **Grunt** | NullClaw fleet | No identity | Instant execution (<2ms boot, ~1MB RAM) with vetted ClawHub skills |
| **Skill Gate** | OpenClaw | Default | On-demand skill vetting — sandbox test → pass/fail |

## Atlas (ACP Bridge)

Atlas is the CLI-agnostic connector. It speaks ACP (Agent Client Protocol) — JSON-RPC 2.0 over NDJSON stdio.

```
ACP_CLI_COMMAND=qwen-code    → Local path (source of truth)
ACP_CLI_COMMAND=claude-code  → Frontier (on checkpoint failure)
ACP_CLI_COMMAND=gemini-cli   → Frontier alternative
ACP_CLI_COMMAND=codex-cli    → Frontier alternative
```

Atlas enables cross-training: the same task can be attempted by multiple backends. The gap between local and frontier results = training signal.

**Files:**
- `pkgs/acp-bridge/acp-bridge.mjs` — 290-line Node.js ACP Bridge
- `pkgs/acp-bridge/default.nix` — Nix package
- `pkgs/acp-bridge/docker-image.nix` — Container image

## Two-Path Execution

```
Task arrives at Hermes (Brain/Wanda)
  │
  ├── Simple → NullClaw Grunt (0.8B or 9B, <2ms boot)
  │
  ├── Complex → Qwen-Agent Engineer (9B ATIC + MCP tools)
  │     │
  │     qwen-code + Qwen-Agent ATIC = source of truth
  │     Generates primary training data
  │
  └── Local fails at checkpoint → escalate to frontier
        │
        claude-code / gemini-cli / codex-cli
        Each uses its OWN native ATIC + tool calling
        NOT constrained to Qwen-Agent's framework
        │
        Gap = training signal → GSPO trains local models
```

Frontier models use their OWN native tool calling. Constraining Claude to Qwen-Agent's tools gives lackluster results. Let each model use what it's best at.

## Identity Seeding

| Component | Identity | Mutable by Hermes? |
|-----------|----------|---------------------|
| Hermes Brain | **Wanda** — `wanda/IDENTITY.md`, `SOUL.md`, `USER.md`, `MEMORY.md` | Yes — MEMORY.md grows |
| Qwen-Agent Engineer | **Cosmo** — `cosmo/IDENTITY.md`, `SOUL.md`, `USER.md` | No — stable builder |
| OpenClaw | Default (none) | No — infrastructure |
| NullClaw Grunts | None | N/A — disposable |

Identity files live in `wanda/` and `cosmo/` directories at the repo root.

## Agent Personalities

Sub-agents are defined in `agents/`:

| Agent | Role | Files |
|-------|------|-------|
| **Coder** | Writes code | `agents/coder/AGENTS.md`, `SOUL.md`, `QWEN.md` |
| **Deployer** | Deploys changes | `agents/deployer/` |
| **Reader** | Reads/analyzes content | `agents/reader/` |
| **Reviewer** | Reviews code/content | `agents/reviewer/` |
| **Writer** | Writes content | `agents/writer/` |

Base system prompt: `agents/SYSTEM.md`

## MCP Servers

Custom MCP servers provide tool capabilities:

| Server | File | Purpose |
|--------|------|---------|
| **Dispatch** | `pkgs/mcp-servers/dispatch.py` | Task routing (code → Cosmo, content → Wanda) |
| **Escalation** | `pkgs/mcp-servers/escalation.py` | 5-tier promotion chain, training data capture |
| **Memory** | `pkgs/mcp-servers/memory.py` | Agent MEMORY.md read/write, FTS5 search |
| **ClawHub** | `pkgs/mcp-servers/clawhub.py` | ClawHub → MCP bridge, on-demand skill vetting |

## Workflows

Task routing and escalation config:

| File | Purpose |
|------|---------|
| `workflows/dispatch.yaml` | Routes tasks by type to queues |
| `workflows/escalation.yaml` | 5-tier promotion chain per domain |
| `workflows/rl-training.yaml` | RL training triggers |
| `workflows/content-task.yaml` | Content generation workflow |
| `workflows/research-task.yaml` | Research workflow |
| `workflows/wp-task.yaml` | WordPress workflow |

## NixOS Services

| Service | File | Host |
|---------|------|------|
| Hermes orchestrator | `modules/services/orchestrator.nix` | NAS |
| OpenClaw fallback | `modules/services/orchestrator-openclaw.nix` | NAS |
| OpenSandbox runtime | `modules/services/opensandbox.nix` | NAS + Workstation |
| Agent task runner | `modules/services/agent-runner.nix` | NAS + Workstation |

## Recursive Self-Improvement

The system can modify its own infrastructure at four levels:

| Level | What | Mechanism | Safety |
|-------|------|-----------|--------|
| Weights | Model parameters | Atropos RL + QLoRA | DQN checkpoint/rollback |
| Prompts | Skills, system prompts | GEPA self-evolution | A/B test old vs new |
| Code | MCP servers, scripts | Qwen-Agent writes code | Git commit + review |
| Infrastructure | Nix configs, services | Engineer proposes | Human approves `nixos-rebuild` |

NixOS makes this safe: every change is declarative, version-controlled, and atomically rollbackable via `nixos-rebuild switch --rollback`.

## Per-Business Learning

The system learns per client:

```
Business A → trajectories tagged "business-a" → domain LoRA adapter
Business B → trajectories tagged "business-b" → domain LoRA adapter
```

SGLang supports LoRA hot-swap — switch adapters per request based on business context. The longer you work with a client, the less you need frontier APIs.
