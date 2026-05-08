# CONTEXT.md

## Language

- **Universal Observer**: OpenClaw instance running in the dotfiles repo. Root authority: manages all client repos, owns Discord/voice gateway, can escalate any client debate. One per physical machine. Runs in `docker-sbx` (KVM-isolated, GPU passthrough, k3s control-plane node). NOT a worker — sits above NullBoiler in the hierarchy.
- **NullBoiler**: Per-repo pull-mode debate pipeline. Polls NullTickets for tasks, claims leases, runs NullClaw↔LogicAgent debate turns as subprocesses, posts artifacts, manages heartbeats. Replaces `ralph_loop.sh`. Each client Living Code Repository runs its own NullBoiler instance.
- **NullTickets**: Durable queue/state machine for tickets. Each client repo has its own NullTickets. Replaces GitHub Issues as the debate trigger. NullBoiler polls via `claim_roles` workflow.
- **Living Code Repository**: A client-owned git repo running the full debate stack: NullClaw (feelings-first, per-client instance) + LogicAgent (logic-first) + NullBoiler (pipeline) + NullTickets (queue). Each client's NullClaw has its own Lucid memory scoped to that repo. OpenClaw observes all Living Code Repositories as Universal Observer.
- **Inference Sandbox**: Dedicated `docker-sbx` KVM worker node running turboquant llama.cpp (`johndpope/llama-cpp-turboquant`) with Qwen3.5-4B at `--ctx-size 32768`. GPU passthrough. Shared across all client nodes. Stateless per-request (no cross-client context). Shared compute tier — disclosed in client contracts. Physical isolation (separate GPU) is the paid upgrade path.
- **Client Node**: One `docker-sbx` KVM worker node per client (internal or external). Provisioned via `git clone` of client repo into the VM. Joins k3s cluster via agent token over Tailscale mesh. Runs openclaw + hindsight + lucid. No GPU. KVM boundary = SOC 2 audit boundary. Inference calls route to control-plane node via Tailscale ACL (client → inference:8080 allowed; client → client DENIED).
- **Control Plane Node**: The dotfiles repo's `docker-sbx` VM. Runs k3s server + GPU passthrough + llama.cpp daemonset. Root of the cluster. Universal Observer lives here.
- **k3s Cluster**: k3s (lightweight Kubernetes) cluster spanning: 1 control-plane node + 1 inference node + N client nodes. kube-audit log per node. RBAC namespace-scoped per client. PVCs via local-path provisioner. `make client-add SLUG=<name>` target provisions new client nodes.
- **Digital Twin**: Ubuntu 24.04 LTS container (`docker/Dockerfile.digital-twin`). Mirrors developer machine: `~/dotfiles` seeded, full `make install` stack (apt, nvm, node, claude, claude-plugins, hindsight, qwen, gemini). Runs automated pipeline (debate → implement → PR) without human interaction. Scoped to project directory; no bare-metal OMC.
- **Two-Layer Architecture**: Layer 1 = human + OMC on bare metal (plans/issues in GitHub, frontier models OK). Layer 2 = digital twin automated pipeline (reads issue → debate → implement → PR, no OMC, local models only).
- **Living Code Repository**: A git repo that evolves autonomously through agent-generated commits, memory updates, and debate transcripts.
- **Debate**: A structured exchange between Nullclaw (feelings-first, host-repo agent) and LogicAgent (logic-first, bicameral-mind engine agent) triggered by new issue or CLI (`make debate`). Seeded from Lucid + Hindsight. Produces a Debate Record. Engine delegated to `bicameral-mind` submodule.
- **Debate Record**: Markdown file committed to `debates/YYYY-MM-DD-<issue-slug>.md`. Contains 3 turns + confidence score.
- **Nullclaw**: Feelings-first debate sub-agent. Inference: Gemma 4 default (Device Model Profile override; e.g. Qwen3.5-4B on resource-constrained hosts) via `hindsight_litellm.completion()` → llama.cpp (`:8080`). Researcher/documentor role. Memory: Lucid MCP (episodic/contextual). Defined in `agents/nullclaw/`.
- **LogicAgent**: Logic-first debate agent in bicameral-mind engine. Inference: Qwen 3.5 default (Device Model Profile override; shares Nullclaw server on resource-constrained hosts) via `qwen_agent.agents.Assistant` → llama.cpp (`:8080` or `:8081`). Does NOT implement directly — delegates to Qwen-Agent sub-agent. Memory: Hindsight MCP (semantic, shared bank). Defined in `bicameral-mind/agents/logicagent/`.
- **CLI Wrapper**: Each model uses the CLI it was trained with — all run INSIDE the container, never on bare metal. Gemma 4 → `gemini -p` (local llama.cpp; Google TOS prohibits personal subscriptions for agentic turns). Qwen 3.5 → `qwen --print`. Claude → `claude --print` (escalation path inside container). Codex CLI also available inside container. All CLI outputs feed Hindsight (containerized bank). Training alignment: native CLI prompt format → higher coherence.
- **Lucid Memory Provider**: MCP server (`localhost:9000`, `lucid-mcp` Docker service). Episodic/spatial/contextual memory. Used by Nullclaw for activity-based recall.
- **Hindsight Memory Provider**: MCP server internal to control-plane container stack. NOT port-forwarded to bare metal. Semantic patterns + anti-patterns, entity resolution. `bank_id` = client slug for per-client isolation. Consumers: (1) OpenClaw Universal Observer — native MCP, reads patterns to seed debates; (2) NullClaw — via `hindsight_litellm` wrapper. Claude Code on bare metal has NO access — bare metal AI must never be influenced by containerized patterns.
- **Pre-Debate Seed**: Combined context injected before Turn 1. Queries Lucid (`/recall`) for episodic framing + Hindsight (`/reflect`) for patterns/anti-patterns. Richer seed each iteration as shared bank grows.
- **Confidence Score**: 0–1 metric from debate frontmatter. Threshold: ≥0.75 × 2 consecutive runs = Ralph Loop exit. Not fully trusted — user adds "needs-help" PR label for manual escalation.
- **Confidence Threshold**: 0.75 × 2 consecutive runs. Ralph Loop exit condition. Signals stable convergence without requiring perfection.
- **Ralph Loop**: `bicameral-mind/scripts/ralph_loop.sh`. Local agents attempt implementation repeatedly (max 10). Each: git reset → debate → Qwen-Agent implements → score via Hindsight → retain. Exit at Confidence Threshold. PR always created at exit.
- **Training Signal**: GitHub PR from `bicameral-mind/scripts/create_training_pr.sh`. Body: debate transcript + Hindsight patterns + confidence scores + git diff. Merge = positive RL signal. Close = negative RL signal. "needs-help" label = manual escalation to Claude Code.
- **Escalation**: Human-triggered (not automated). User adds "needs-help" label or runs `make escalate ISSUE_URL=...`. Invokes `claude --print "Implement the GitHub issue at $ISSUE_URL"` — issue URL is sole context, no plan file.
- **Distillation**: Container-side AI stack (Claude escalation, Qwen, Gemini, Codex, NullClaw, LogicAgent) outputs feed Hindsight inside the container → surfaces past experiences for future container debates. Bare metal observes container outputs only via PR merge/close signals (positive/negative RL) — never reads Hindsight. Two intelligence layers: (1) bare metal = human + frontier AI, clean + SOC 2 compliant; (2) container = autonomous local AI stack, self-improving via Hindsight. Data flow: bare metal → container only. Container never muddies bare metal reasoning.
- **Bicameral Mind**: Git submodule at `bicameral-mind/` containing the debate engine, LogicAgent, docker stack, and ralph/escalation scripts. Host repos provide their own agent (e.g. nullclaw); bicameral-mind provides LogicAgent + orchestration. Makefile targets delegate via `make -C bicameral-mind`.
- **Issue Agent**: Per-issue digital twin instance scoped to project dir. Spawns freely. Distinct from Universal Observer.
- **OMC Path**: Human + Claude Code + OMC on bare metal. Drives Layer 1 (planning, issue creation, escalation review). Not present in digital twin automated pipeline.
- **Discord Forum Thread**: Live activity log for a debate posted to forum channel `1501647240727367711`. One thread per issue, created by `ralph_loop.sh` at debate start. Bidirectional — user replies within the thread are injected as feedback into the active debate session via OpenClaw thread binding (`/focus`).
- **Discord Interaction Channel**: Guild text channel `1501720991347249383` where the user sends messages to the OpenClaw agent directly. No `@mention` required (private server). OpenClaw reply target for outbound proactive messages.
- **Discord Privacy Mode**: DM-based conversation with the OpenClaw agent for sensitive/private interactions. Allowlisted to user `140186601912270849` only.
- **Discord Voice Channel**: `1501741347013660885`. Bot auto-joins on gateway start. STT via faster-whisper (large-v3), TTS via Kokoro (CPU). Real-time voice conversation.
- **Discord General Channel**: Guild text channel `1403055310305759386` (#general). `@mention` required. Future venue for multi-bot discussions — bots @mention each other to route turns.
- **Client Discord Setup**: Default = one Discord app + bot token per client (full brand separation, own access control). Lightweight alternative = client invited into existing server, their guild added to `allowFrom` in `openclaw.json`. One bot per client is the right default; existing-server onboarding is the fast path for early clients.
- **Bot Presence**: Discord status signal for the OpenClaw agent. Default: Online. During active debate: DND + activity text "Debating: `<issue-slug>`". On debate exit: Online, activity cleared. Updated by `ralph_loop.sh` via OpenClaw presence API. One thread per issue, created by `ralph_loop.sh` at debate start. Each agent turn posted verbatim. @mention `<@140186601912270849>` only on confident exit (≥0.75×2) or max attempts exhausted. Replaces flat channel message.
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
