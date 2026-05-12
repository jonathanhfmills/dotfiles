# Glossary

**Bicameral Mind**:
Git submodule at `bicameral-mind/` containing the debate engine, LogicAgent, docker stack, and ralph/escalation scripts. Host repos provide their own agent (e.g. Nullclaw); Bicameral Mind provides LogicAgent + orchestration.

**Bot Presence**:
Discord status signal for the OpenClaw agent. Default: Online. During active debate: DND + activity text "Debating: `<issue-slug>`". On debate exit: Online, activity cleared.

**CLI Wrapper**:
Each model uses the CLI it was trained with — all run inside the container, never on bare metal. Gemma 4 → `gemini -p`. Qwen 3.5 → `qwen --print`. Claude → `claude --print` (escalation path). Training alignment: native CLI prompt format → higher coherence.

**Client Discord Setup**:
Default = one Discord app + bot token per client (full brand separation, own access control). Lightweight alternative = client invited into existing server, their guild added to `allowFrom` in `openclaw.json`.

**Client Node**:
One `docker-sbx` KVM worker node per client. Runs openclaw + hindsight + lucid. No GPU. KVM boundary = SOC 2 audit boundary. Inference calls route to control-plane node via Tailscale ACL (client → inference:8080 allowed; client → client DENIED).

**Confidence Score**:
0–1 metric from debate frontmatter. Threshold: ≥0.75 × 2 consecutive runs = Ralph Loop exit.
_Avoid_: score, rating

**Confidence Threshold**:
Exit condition for the Ralph Loop: ≥0.75 × 2 consecutive runs. Signals stable convergence without requiring perfection.

**Control Plane Node**:
The dotfiles repo's `docker-sbx` VM. Runs k3s server + GPU passthrough + llama.cpp daemonset. Root of the cluster. Universal Observer lives here.

**Debate**:
A structured exchange between Nullclaw (feelings-first) and LogicAgent (logic-first) triggered by a new issue or CLI (`make debate`). Seeded from Lucid + Hindsight. Produces a Debate Record. Engine delegated to `bicameral-mind` submodule.

**Debate Record**:
Markdown file committed to `debates/YYYY-MM-DD-<issue-slug>.md`. Contains 3 turns + Confidence Score.

**Device Model Profile**:
Per-host `.env` overrides for inference. On resource-constrained hosts, both Nullclaw and LogicAgent may share a single model rather than dedicated per-agent models. GPU/VRAM determines quant choice.

**Digital Twin**:
Ubuntu 24.04 LTS container (`docker/Dockerfile.digital-twin`). Mirrors developer machine. Runs automated pipeline (debate → implement → PR) without human interaction. Scoped to project directory; no bare-metal OMC.

**Discord Forum Thread**:
Live activity log for a debate posted to forum channel `1501647240727367711`. One thread per issue. Bidirectional — user replies within the thread are injected as feedback into the active debate session via OpenClaw thread binding (`/focus`).

**Discord General Channel**:
Guild text channel `1403055310305759386` (#general). `@mention` required. Future venue for multi-bot discussions.

**Discord Interaction Channel**:
Guild text channel `1501720991347249383` where the user sends messages to the OpenClaw agent directly. No `@mention` required (private server). OpenClaw reply target for outbound proactive messages.

**Discord Privacy Mode**:
DM-based conversation with the OpenClaw agent for sensitive/private interactions. Allowlisted to user `140186601912270849` only.

**Discord Voice Channel**:
Channel `1501741347013660885`. Bot auto-joins on gateway start. STT via faster-whisper (large-v3), TTS via Kokoro (CPU). Real-time voice conversation.

**Distillation**:
Container-side AI outputs (Claude escalation, Qwen, Gemini, Codex, Nullclaw, LogicAgent) feed Hindsight inside the container → surfaces past experiences for future debates. Bare metal observes container outputs only via PR merge/close signals. Data flow: bare metal → container only.

**Dotfiles Template**:
`jonathanhfmills/dotfiles` GitHub template repo. Upstream source for all Host Repos. Changes propagate to host repos via `make sync-upstream`.

**Escalation**:
Human-triggered (not automated). User adds "needs-help" label or runs `make escalate ISSUE_URL=...`. Invokes `claude --print "Implement the GitHub issue at $ISSUE_URL"` — issue URL is sole context, no plan file.

**Hindsight Memory Provider**:
MCP server internal to the control-plane container stack. NOT port-forwarded to bare metal. Semantic patterns + anti-patterns, entity resolution. `bank_id` = client slug for per-client isolation. Claude Code on bare metal has NO access.
_Avoid_: Hindsight MCP, shared memory bank

**Host Fleet**:
The four derived Host Repos: `dotfiles-laptop`, `dotfiles-laptop-work`, `dotfiles-desktop`, `dotfiles-desktop-work`. Each has its own Device Model Profile and llama.cpp config.

**Host Repo**:
Per-device git repo derived from the Dotfiles Template (e.g. `dotfiles-laptop`). Carries device-specific `.env`. `git remote upstream` tracks template for sync.

**Inference Sandbox**:
Dedicated `docker-sbx` KVM worker node running turboquant llama.cpp with Qwen3.5-4B at `--ctx-size 32768`. GPU passthrough. Shared across all client nodes. Stateless per-request (no cross-client context).

**Issue Agent**:
Per-issue Digital Twin instance scoped to a project directory. Spawns freely. Distinct from Universal Observer.

**k3s Cluster**:
Lightweight Kubernetes cluster spanning: 1 control-plane node + 1 inference node + N client nodes. kube-audit log per node. RBAC namespace-scoped per client.

**Living Code Repository**:
A client-owned git repo running the full debate stack (Nullclaw + LogicAgent + NullBoiler + NullTickets) that evolves autonomously through agent-generated commits, memory updates, and debate transcripts.

**LogicAgent**:
Logic-first debate agent in the Bicameral Mind engine. Inference: Qwen 3.5 default via `qwen_agent.agents.Assistant` → llama.cpp. Does NOT implement directly — delegates to Qwen-Agent sub-agent. Memory: Hindsight Memory Provider (semantic, shared bank). Defined in `bicameral-mind/agents/logicagent/`.

**Lucid Memory Provider**:
MCP server (`localhost:9000`, `lucid-mcp` Docker service). Episodic/spatial/contextual memory. Used by Nullclaw for activity-based recall.
_Avoid_: Lucid MCP

**NullBoiler**:
Per-repo pull-mode debate pipeline. Polls NullTickets for tasks, claims leases, runs Nullclaw↔LogicAgent debate turns as subprocesses, posts artifacts, manages heartbeats. Replaces `ralph_loop.sh`. Each client Living Code Repository runs its own NullBoiler instance.

**Nullclaw**:
Feelings-first debate sub-agent. Inference: Gemma 4 default (Device Model Profile override) via `hindsight_litellm.completion()` → llama.cpp. Researcher/documentor role. Memory: Lucid Memory Provider (episodic). Defined in `agents/nullclaw/`.

**NullTickets**:
Durable queue/state machine for tickets. Each client repo has its own NullTickets. Replaces GitHub Issues as the debate trigger. NullBoiler polls via `claim_roles` workflow.

**OMC Path**:
Human + Claude Code + OMC on bare metal. Drives Layer 1 (planning, issue creation, escalation review). Not present in the Digital Twin automated pipeline.

**OpenClaw**:
Orchestrator agent. Owns turn routing, memory coordination, git commit, GitHub comments, Discord replies, and confidence scoring. Nullclaw and LogicAgent are pure debaters — OpenClaw is not a debater.
_Avoid_: Hermes (retired name)

**Pre-Debate Seed**:
Combined context injected before Turn 1. Queries Lucid (`/recall`) for episodic framing + Hindsight (`/reflect`) for patterns/anti-patterns.

**Ralph Loop**:
`bicameral-mind/scripts/ralph_loop.sh`. Local agents attempt implementation repeatedly (max 10). Each: git reset → debate → Qwen-Agent implements → score via Hindsight → retain. Exit at Confidence Threshold. PR always created at exit.

**Training Signal**:
GitHub PR from `bicameral-mind/scripts/create_training_pr.sh`. Body: debate transcript + Hindsight patterns + confidence scores + git diff. Merge = positive RL signal. Close = negative RL signal.

**Two-Layer Architecture**:
Layer 1 = human + OMC on bare metal (plans/issues in GitHub, frontier models OK). Layer 2 = Digital Twin automated pipeline (reads issue → debate → implement → PR, no OMC, local models only).

**Universal Observer**:
The singleton OpenClaw instance running in the dotfiles repo. Root authority: manages all client repos, owns Discord/voice gateway, can escalate any client debate. One per physical machine. Runs in `docker-sbx` (KVM-isolated, GPU passthrough, k3s control-plane node).
