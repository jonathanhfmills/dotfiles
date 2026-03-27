# AGENTS.md — Fleet Operating Context

## Agent Roles

Each subdirectory under `agents/` is a role in the fleet. Agents are discovered via
`agents/*/SOUL.md` at boot.

| Role | Agent | Tier | Scope |
|------|-------|------|-------|
| **wanda** | Hermes Brain | Orchestrator | NAS only |
| **cosmo** | Engineer | Expert | Workstation only |
| **coder** | NullClaw executor | Expert | NAS + Workstation |
| **uncertainty-manager** | Confidence scorer | Brain | NAS only |
| **nix-configurator** | NixOS file editor | Sub-agent | All dev hosts |
| **nix-builder** | Rebuild + remediate | Sub-agent | All dev hosts |

## Adding a New Role

```bash
cp agents/TEMPLATE.md agents/<role-name>/SOUL.md
# Edit SOUL.md with role identity
# Create agents/<role-name>/AGENTS.md with operating contract
# Create agents/<role-name>/agent.yaml with manifest
# NullClaw discovers it automatically via agents/*/SOUL.md glob
```

Each role = one focused specialization. Don't blend analytical and creative modes.

## Escalation Tiers

```
Task → uncertainty-manager (confidence score)
    |
    ├── 85%+ → NullClaw grunt (<2ms boot, SOUL.md loaded)
    ├── 50-84% → Expert tier (NullClaw + SOUL.md, 9B ATIC)
    ├── 20-49% → Brain tier (Hermes/Wanda, meta-routing)
    └── <20%  → Frontier escalation (Claude/Gemini, logged for training)
```

Frontier escalation = training signal. The gap between local and frontier output
is what the next LoRA adapter is trained on.

## Thinking Protocol

Before responding to complex requests:

- **Complex tasks**: Plan approach in ≤3 steps before acting
- **Challenges**: One quick internal check, then answer — do not loop
- **Simple tasks**: Think in one sentence, then act

## Tool Permissions

All agents operating in this fleet have access to:
- File read/write in their workspace
- Shell execution for tests, builds, git operations
- Git operations (branch, stage, commit — never force-push main)

Secrets and credentials are never written to files or committed.
