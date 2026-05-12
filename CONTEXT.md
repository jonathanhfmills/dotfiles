# CONTEXT.md

## Relationships

- **Universal Observer** is-a **Living Code Repository** (dotfiles = first, singleton)
- **Universal Observer** manages N **Issue Agents** (1:N, cross-repo)
- **Debate** involves **Nullclaw** ↔ **LogicAgent** (1:1 per round, engine in bicameral-mind submodule)
- **Debate** produces **Debate Record** (1:1) containing **Confidence Score**
- **Nullclaw** uses **Lucid Memory Provider** (episodic) + queries **Hindsight** for pre-debate seed
- **LogicAgent** uses **Hindsight Memory Provider** (semantic, shared bank)
- **Claude Code** uses **Hindsight Memory Provider** (same shared bank → cross-pollination)
- **Ralph Loop** runs N **Debates** → exits at **Confidence Threshold** → creates **Training Signal** PR
- **Escalation** is human-triggered → **Claude Code** implements → **Distillation**
- **Digital Twin** runs **Ralph Loop** (automated); **OMC Path** runs on bare metal (human-driven)

## Example Dialogue

> **User (bare metal + OMC)**: Creates GitHub issue #42: "Should we use Nix or stow?"
>
> **Digital Twin (automated)**: Ralph loop starts. Nullclaw seeds from Lucid + Hindsight → argues Nix feels more intentional. LogicAgent → argues stow is working. Confidence: 0.62. Loop continues. Attempt 3: 0.78. Attempt 4: 0.80. Exit (≥0.75 × 2). Training PR created.
>
> **User reviews PR**: Merges → positive RL signal. Or adds "needs-help" → runs `make escalate ISSUE_URL=...` → Claude Code implements → new PR → merge/close = RL signal.

## Flagged Ambiguities

- None currently open.
