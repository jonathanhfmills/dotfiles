# CONTEXT.md

## Language

- **Universal Observer**: The singleton openclaw instance running in the dotfiles repo — root maintainer agent, #1 info source, has access rights to manage all other repo containers. Only one containerized instance.
- **Digital Twin**: Ubuntu 24.04 LTS container (`docker/Dockerfile.digital-twin`). Mirrors developer machine: `~/dotfiles` seeded, full `make install` stack (apt, nvm, node, claude, claude-plugins, hindsight, qwen, gemini). Runs automated pipeline (debate → implement → PR) without human interaction. Scoped to project directory; no bare-metal OMC.
- **Two-Layer Architecture**: Layer 1 = human + OMC on bare metal (plans/issues in GitHub, frontier models OK). Layer 2 = digital twin automated pipeline (reads issue → debate → implement → PR, no OMC, local models only).
- **Living Code Repository**: A git repo that evolves autonomously through agent-generated commits, memory updates, and debate transcripts.
- **Debate**: A structured exchange between Nullclaw (feelings-first) and Hermes (logic-first) triggered by new issue or CLI (`make debate`). Seeded from Lucid + Hindsight. Produces a Debate Record.
- **Debate Record**: Markdown file committed to `debates/YYYY-MM-DD-<issue-slug>.md`. Contains 3 turns + confidence score.
- **Nullclaw**: Feelings-first debate sub-agent. Inference: Gemma 4 via `hindsight_litellm.completion()` → llama.cpp (`:8080`). Researcher/documentor role. Memory: Lucid MCP (episodic/contextual). Defined in `agents/nullclaw/`.
- **Hermes**: Logic-first Universal Observer and debate orchestrator. Inference: Qwen 3.5 via `qwen_agent.agents.Assistant` → llama.cpp (`:8081`). Does NOT implement directly — delegates to Qwen-Agent sub-agent. Memory: Hindsight MCP (semantic, shared bank). Defined in `agents/hermes/`.
- **CLI Wrapper**: Each model uses the CLI it was trained with. Gemma 4 → `gemini -p` (local llama.cpp only; Google TOS prohibits personal subscriptions for agentic turns). Qwen 3.5 → `qwen --print`. Claude → `claude --print` (escalation only). Training alignment: native CLI prompt format → higher coherence.
- **Lucid Memory Provider**: MCP server (`localhost:9000`, `lucid-mcp` Docker service). Episodic/spatial/contextual memory. Used by Nullclaw for activity-based recall.
- **Hindsight Memory Provider**: Local MCP server (`localhost:8888`, `hindsight-mcp` Docker service, Ollama provider). Semantic patterns + anti-patterns, entity resolution. Shared bank used by Hermes AND Claude Code for cross-pollination. Install via `make hindsight`.
- **Pre-Debate Seed**: Combined context injected before Turn 1. Queries Lucid (`/recall`) for episodic framing + Hindsight (`/reflect`) for patterns/anti-patterns. Richer seed each iteration as shared bank grows.
- **Confidence Score**: 0–1 metric from debate frontmatter. Threshold: ≥0.75 × 2 consecutive runs = Ralph Loop exit. Not fully trusted — user adds "needs-help" PR label for manual escalation.
- **Confidence Threshold**: 0.75 × 2 consecutive runs. Ralph Loop exit condition. Signals stable convergence without requiring perfection.
- **Ralph Loop**: `scripts/ralph_loop.sh`. Local agents attempt implementation repeatedly (max 10). Each: git reset → debate → Qwen-Agent implements → score via Hindsight → retain. Exit at Confidence Threshold. PR always created at exit.
- **Training Signal**: GitHub PR from `create_training_pr.sh`. Body: debate transcript + Hindsight patterns + confidence scores + git diff. Merge = positive RL signal. Close = negative RL signal. "needs-help" label = manual escalation to Claude Code.
- **Escalation**: Human-triggered (not automated). User adds "needs-help" label or runs `make escalate ISSUE_URL=...`. Invokes `claude --print "Implement the GitHub issue at $ISSUE_URL"` — issue URL is sole context, no plan file.
- **Distillation**: Claude Code implementations committed back → Hindsight shared bank accumulates patterns → future debates seeded with richer context → local agents improve over time.
- **Issue Agent**: Per-issue digital twin instance scoped to project dir. Spawns freely. Distinct from Universal Observer.
- **OMC Path**: Human + Claude Code + OMC on bare metal. Drives Layer 1 (planning, issue creation, escalation review). Not present in digital twin automated pipeline.

## Relationships

- **Universal Observer** is-a **Living Code Repository** (dotfiles = first, singleton)
- **Universal Observer** manages N **Issue Agents** (1:N, cross-repo)
- **Debate** involves **Nullclaw** ↔ **Hermes** (1:1 per round, orchestrated by Hermes)
- **Debate** produces **Debate Record** (1:1) containing **Confidence Score**
- **Nullclaw** uses **Lucid Memory Provider** (episodic) + queries **Hindsight** for pre-debate seed
- **Hermes** uses **Hindsight Memory Provider** (semantic, shared bank)
- **Claude Code** uses **Hindsight Memory Provider** (same shared bank → cross-pollination)
- **Ralph Loop** runs N **Debates** → exits at **Confidence Threshold** → creates **Training Signal** PR
- **Escalation** is human-triggered → **Claude Code** implements → **Distillation**
- **Digital Twin** runs **Ralph Loop** (automated); **OMC Path** runs on bare metal (human-driven)

## Example Dialogue

> **User (bare metal + OMC)**: Creates GitHub issue #42: "Should we use Nix or stow?"
>
> **Digital Twin (automated)**: Ralph loop starts. Nullclaw seeds from Lucid + Hindsight → argues Nix feels more intentional. Hermes orchestrates → argues stow is working. Confidence: 0.62. Loop continues. Attempt 3: 0.78. Attempt 4: 0.80. Exit (≥0.75 × 2). Training PR created.
>
> **User reviews PR**: Merges → positive RL signal. Or adds "needs-help" → runs `make escalate ISSUE_URL=...` → Claude Code implements → new PR → merge/close = RL signal.

## Flagged Ambiguities

- None currently open.
