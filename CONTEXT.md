# CONTEXT.md

## Language

- **Universal Observer**: The singleton openclaw instance running in the dotfiles repo — root maintainer agent, #1 info source, has access rights to manage all other repo containers. Only one containerized instance.
- **Digital Twin**: Ubuntu 24.04 LTS container (`docker/Dockerfile.digital-twin`). Mirrors developer machine: `~/dotfiles` seeded, full `make install` stack (apt, nvm, node, claude, claude-plugins, hindsight, qwen, gemini). Runs automated pipeline (debate → implement → PR) without human interaction. Scoped to project directory; no bare-metal OMC.
- **Two-Layer Architecture**: Layer 1 = human + OMC on bare metal (plans/issues in GitHub, frontier models OK). Layer 2 = digital twin automated pipeline (reads issue → debate → implement → PR, no OMC, local models only).
- **Living Code Repository**: A git repo that evolves autonomously through agent-generated commits, memory updates, and debate transcripts.
- **Debate**: A structured exchange between Nullclaw (feelings-first, host-repo agent) and LogicAgent (logic-first, bicameral-mind engine agent) triggered by new issue or CLI (`make debate`). Seeded from Lucid + Hindsight. Produces a Debate Record. Engine delegated to `bicameral-mind` submodule.
- **Debate Record**: Markdown file committed to `debates/YYYY-MM-DD-<issue-slug>.md`. Contains 3 turns + confidence score.
- **Nullclaw**: Feelings-first debate sub-agent. Inference: Gemma 4 default (Device Model Profile override; e.g. Qwen3.5-4B on resource-constrained hosts) via `hindsight_litellm.completion()` → llama.cpp (`:8080`). Researcher/documentor role. Memory: Lucid MCP (episodic/contextual). Defined in `agents/nullclaw/`.
- **LogicAgent**: Logic-first debate agent in bicameral-mind engine. Inference: Qwen 3.5 default (Device Model Profile override; shares Nullclaw server on resource-constrained hosts) via `qwen_agent.agents.Assistant` → llama.cpp (`:8080` or `:8081`). Does NOT implement directly — delegates to Qwen-Agent sub-agent. Memory: Hindsight MCP (semantic, shared bank). Defined in `bicameral-mind/agents/logicagent/`.
- **CLI Wrapper**: Each model uses the CLI it was trained with. Gemma 4 → `gemini -p` (local llama.cpp only; Google TOS prohibits personal subscriptions for agentic turns). Qwen 3.5 → `qwen --print`. Claude → `claude --print` (escalation only). Training alignment: native CLI prompt format → higher coherence.
- **Lucid Memory Provider**: MCP server (`localhost:9000`, `lucid-mcp` Docker service). Episodic/spatial/contextual memory. Used by Nullclaw for activity-based recall.
- **Hindsight Memory Provider**: Local MCP server (`localhost:8888`, `hindsight-mcp` Docker service, Ollama provider). Semantic patterns + anti-patterns, entity resolution. Shared bank used by LogicAgent AND Claude Code for cross-pollination. Install via `make hindsight`.
- **Pre-Debate Seed**: Combined context injected before Turn 1. Queries Lucid (`/recall`) for episodic framing + Hindsight (`/reflect`) for patterns/anti-patterns. Richer seed each iteration as shared bank grows.
- **Confidence Score**: 0–1 metric from debate frontmatter. Threshold: ≥0.75 × 2 consecutive runs = Ralph Loop exit. Not fully trusted — user adds "needs-help" PR label for manual escalation.
- **Confidence Threshold**: 0.75 × 2 consecutive runs. Ralph Loop exit condition. Signals stable convergence without requiring perfection.
- **Ralph Loop**: `bicameral-mind/scripts/ralph_loop.sh`. Local agents attempt implementation repeatedly (max 10). Each: git reset → debate → Qwen-Agent implements → score via Hindsight → retain. Exit at Confidence Threshold. PR always created at exit.
- **Training Signal**: GitHub PR from `bicameral-mind/scripts/create_training_pr.sh`. Body: debate transcript + Hindsight patterns + confidence scores + git diff. Merge = positive RL signal. Close = negative RL signal. "needs-help" label = manual escalation to Claude Code.
- **Escalation**: Human-triggered (not automated). User adds "needs-help" label or runs `make escalate ISSUE_URL=...`. Invokes `claude --print "Implement the GitHub issue at $ISSUE_URL"` — issue URL is sole context, no plan file.
- **Distillation**: Claude Code implementations committed back → Hindsight shared bank accumulates patterns → future debates seeded with richer context → local agents improve over time.
- **Bicameral Mind**: Git submodule at `bicameral-mind/` containing the debate engine, LogicAgent, docker stack, and ralph/escalation scripts. Host repos provide their own agent (e.g. nullclaw); bicameral-mind provides LogicAgent + orchestration. Makefile targets delegate via `make -C bicameral-mind`.
- **Issue Agent**: Per-issue digital twin instance scoped to project dir. Spawns freely. Distinct from Universal Observer.
- **OMC Path**: Human + Claude Code + OMC on bare metal. Drives Layer 1 (planning, issue creation, escalation review). Not present in digital twin automated pipeline.
- **Discord Forum Thread**: Live activity log for a debate posted to forum channel `1501631748880990310`. One thread per issue, created by `ralph_loop.sh` at debate start. Each agent turn posted verbatim. @mention `<@140186601912270849>` only on confident exit (≥0.75×2) or max attempts exhausted. Replaces flat channel message.
- **Dotfiles Template**: `jonathanhfmills/dotfiles` GitHub template repo. Upstream source for all Host Repos. Contains shared scripts, Makefile, and bicameral-mind submodule. Changes propagate to host repos via `make sync-upstream`.
- **Host Repo**: Per-device git repo derived from Dotfiles Template (e.g. `dotfiles-laptop`). Carries device-specific `.env` (model, GPU, VRAM, model server URL). `git remote upstream` tracks template for sync.
- **Host Fleet**: The four derived Host Repos: `dotfiles-laptop`, `dotfiles-laptop-work`, `dotfiles-desktop`, `dotfiles-desktop-work`. Each host has its own Device Model Profile and llama.cpp config.
- **Device Model Profile**: Per-host `.env` overrides for inference. On resource-constrained hosts, both Nullclaw and LogicAgent may share a single model (e.g. `Qwen3.5-4B` on `:8080`) rather than dedicated per-agent models. GPU/VRAM determines quant choice.

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
