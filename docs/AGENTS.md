# The Complexity Engine: Mixture of Experts Agent Architecture

## Overview

A self-improving agent fleet where each role is an expert in the mixture. NullClaw grunts load `SOUL.md` files and hit SGLang/vLLM directly — native `qwen3_coder` tool calling in the inference engine means no middleware frameworks needed.

| Role | Agent | Host | What it does |
|------|-------|------|-------------|
| **Brain** | Hermes Agent | Wanda (NAS) | Routes tasks, learns patterns, self-improves via Atropos RL + GEPA |
| **Expert** | NullClaw + SOUL.md | Any | Loads role-specific expert identity, hits model API with native ATIC |
| **Grunt** | NullClaw fleet | Any | Instant execution (<2ms boot, ~1MB RAM) with vetted ClawHub skills |
| **Skill Gate** | OpenClaw (FLame Guard) | Wanda | On-demand skill vetting — sandbox test → pass/fail |

## The Pipeline

```
Nanodispatch → Experiment → Bench → CSPO → Production
```

1. **Nanodispatch**: Task arrives → UncertaintyManager scores confidence → routes to tier
2. **Experiment**: NullClaw grunt loads SOUL.md, executes task, captures trajectory
3. **Bench**: 35B-A3B MoE evaluator scores completion quality (overnight)
4. **CSPO**: Chemistry of Problems and Solutions — results documented and published
5. **Production**: Validated LoRA adapters deployed per-business

## Mixture of Experts

Each `agents/*/SOUL.md` = one expert role in the mixture. NullClaw discovers roles via `agents/*/SOUL.md` glob.

| Expert Role | Specialization | Default Tier |
|-------------|---------------|-------------|
| **coder** | Code authoring, tests, implementation | 9B GPU |
| **uncertainty-manager** | Confidence scoring, routing, calibration | 9B (Brain) |

### Adding a New Expert

```bash
# Write a new agent role - create in cdp-cluster
cp agents/TEMPLATE.md agents/<role-name>/SOUL.md
# Edit SOUL.md with role-specific identity
# Create AGENTS.md with operating contract
# NullClaw discovers it automatically
```

## Native ATIC (No Middleware)

Both SGLang and vLLM support `--tool-call-parser qwen3_coder` natively. The model weights already know how to call tools — the inference engine parses the output into OpenAI-compatible `tool_calls`.

```
NullClaw grunt                    SGLang / vLLM
    │                                  │
    ├── loads SOUL.md (expert role)     │
    ├── sends {messages, tools} ──────►│
    │                                  ├── model generates tool calls
    │                                  ├── qwen3_coder parser formats output
    │◄── receives {tool_calls} ────────┤
    ├── executes tools locally         │
    └── returns result                 │
```

No Qwen-Agent, no Python middleware, no framework overhead. Direct API calls.

## Atlas (ACP Bridge)

Atlas is the CLI-agnostic connector for cross-training. It speaks ACP (Agent Client Protocol) — JSON-RPC 2.0 over NDJSON stdio.

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

## Routing (UncertaintyManager)

```
Task arrives at Hermes (Brain/Wanda)
  │
  ├── UncertaintyManager scores confidence
  │
  ├── 85%+ → Nanodispatch → NullClaw grunt (SOUL.md + 0.8B or 9B)
  │
  ├── 50-84% → NullClaw + coder SOUL (9B, ATIC + tools)
  │
  ├── 20-49% → Brain (Hermes, meta-learning)
  │
  └── <20% → Frontier escalation (claude-code/gemini-cli/codex-cli)
              Logged for training — gap = signal
```

## Identity Seeding

| Component | Identity | Mutable by Hermes? |
|-----------|----------|---------------------|
| Hermes Brain | **Wanda** — `wanda/IDENTITY.md`, `SOUL.md`, `USER.md`, `MEMORY.md` | Yes — MEMORY.md grows |
| NullClaw Experts | SOUL.md per role — `agents/*/SOUL.md` | Yes — agents evolve their own files |
| OpenClaw | Default (none) | No — infrastructure |
| NullClaw Grunts | None | N/A — disposable |

Identity files live in `wanda/` and `cosmo/` directories at the repo root.

## Infrastructure Naming

| Internal Name | Implementation | Purpose |
|--------------|----------------|---------|
| **Nanodispatch** | UncertaintyManager + NullClaw | Sub-ms task routing |
| **cdp-cluster** | NixOS fleet + OpenSandbox | Agent role hosting |
| **cp-cluster** | ClawHub + NullClaw | Skill deployment |
| **Model Zoo** | Inference tiers (0.8B/9B/35B/Frontier) | Curated models with ATIC support |
| **FLame Guard** | OpenClaw vetting gateway | Federated learning security |
| **GEPA** | DSPy genetic-Pareto optimization | Self-evolution without GPU training |
| **CSPO** | GitHub Pages publication | Chemistry of Problems and Solutions |

## MCP Servers

Custom MCP servers provide tool capabilities:

| Server | File | Purpose |
|--------|------|---------|
| **Dispatch** | `pkgs/mcp-servers/dispatch.py` | Task routing (code → Cosmo, content → Wanda) |
| **Escalation** | `pkgs/mcp-servers/escalation.py` | 5-tier promotion chain, training data capture |
| **Memory** | `pkgs/mcp-servers/memory.py` | Agent MEMORY.md read/write, FTS5 search |
| **ClawHub** | `pkgs/mcp-servers/clawhub.py` | ClawHub → MCP bridge, on-demand skill vetting |

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
| Code | MCP servers, scripts | NullClaw + coder SOUL writes code | Git commit + review |
| Infrastructure | Nix configs, services | Proposed changes | Human approves `nixos-rebuild` |

NixOS makes this safe: every change is declarative, version-controlled, and atomically rollbackable via `nixos-rebuild switch --rollback`.

## Per-Business Learning

The system learns per client:

```
Business A → trajectories tagged "business-a" → domain LoRA adapter
Business B → trajectories tagged "business-b" → domain LoRA adapter
```

SGLang supports LoRA hot-swap — switch adapters per request based on business context. The longer you work with a client, the less you need frontier APIs.
