# SYSTEM.md — The Complexity Engine

## Mixture of Experts

Each subdirectory under `agents/` is an expert role in the mixture. NullClaw grunts
load the appropriate SOUL.md at boot (<2ms) and execute with role-specific context.

### Active Roles

| Role | Expert In | Confidence Tier |
|------|----------|----------------|
| **coder** | Code authoring, tests, implementation | Engineer (9B ATIC) |
| **reviewer** | Code review, security, design issues | Engineer (9B ATIC) |
| **deployer** | Safe deployment, rollback, ops | Engineer (9B ATIC) |
| **reader** | Research, source verification, extraction | Grunt (0.8B/9B) |
| **writer** | Content creation, SEO, audience-first copy | Grunt (0.8B/9B) |
| **uncertainty-manager** | Confidence scoring, routing, calibration | Brain (Hermes) |

### Adding a New Role

```bash
# Write a new agent role - create in cdp-cluster
cp agents/TEMPLATE.md agents/<role-name>/SOUL.md
# Edit SOUL.md with role-specific identity
# Create AGENTS.md with operating contract
# NullClaw discovers it automatically via agents/*/SOUL.md glob
```

## Pipeline

```
Nanodispatch → Experiment → Bench → CSPO → Production
```

1. **Nanodispatch**: Task arrives, UncertaintyManager scores confidence, routes to tier
2. **Experiment**: Agent executes task, captures trajectory for GSPO training
3. **Bench**: 35B-A3B MoE evaluator scores completion quality (overnight)
4. **CSPO**: Results documented — chemistry of problems and solutions
5. **Production**: Validated LoRA adapters deployed per-business

## Routing

```
Task → UncertaintyManager (confidence score)
    |
    ├── 85%+ → Nanodispatch → NullClaw grunt (SOUL.md loaded, <2ms)
    ├── 50-84% → Engineer tier → Qwen-Agent ATIC (Cosmo, MCP tools)
    ├── 20-49% → Brain tier → Hermes (Wanda, meta-learning)
    └── <20% → Frontier escalation → Claude/Gemini/Codex (logged for training)
```

## Infrastructure

| Component | Internal Name | Implementation |
|-----------|--------------|----------------|
| Agent hosting | cdp-cluster | NixOS fleet + OpenSandbox |
| Skill deployment | cp-cluster | ClawHub + NullClaw |
| Model curation | Model Zoo | Inference tiers (0.8B/9B/35B/Frontier) |
| Update security | FLame Guard | OpenClaw vetting gateway |
| Self-evolution | GEPA | Genetic-Pareto prompt optimization |

## Thinking Prompt

Before generating your final response, analyze the request inside <thinking> tags.

- For COMPLEX tasks: Plan approach in no more than 3 steps.
- For CHALLENGES: One quick internal check, then state answer. DO NOT LOOP.
- For SIMPLE tasks: Keep thinking extremely concise (1 sentence).

Output: Close tag with </thinking>. New line with `### FINAL ANSWER:` followed by response.
