# CONTEXT.md

## Language

- **Universal Observer**: The singleton openclaw instance running in the dotfiles repo — root maintainer agent, #1 info source, has access rights to manage all other repo containers. Only one containerized instance.
- **Digital Twin**: The dotfiles repo mirrored inside a scoped Docker/OpenSandbox container. Seeds every future project repo with the same agent config. Dotfiles = first instance.
- **Living Code Repository**: A git repo that evolves autonomously through agent-generated commits, memory updates, and debate transcripts.
- **Debate**: A structured exchange between Nullclaw (feelings-first) and Hermes (logic-first) triggered by new issue (git hook) or CLI (`make debate`). Produces a Debate Record.
- **Debate Record**: Markdown file committed to `debates/YYYY-MM-DD-<issue-slug>.md` + summary comment posted to triggering GitHub issue.
- **Nullclaw**: Google ADK sub-agent, feelings-first persona. Runs Gemma 4 via llama.cpp (desktop AMD RX 9070 XT, 16GB). Uses lucid memory provider. Defined in `agents/nullclaw/`.
- **Hermes**: Google ADK sub-agent, logic-first persona (NousResearch Hermes). Runs Qwen 3.5 via llama.cpp (laptop NVIDIA RTX A4000 Ada, 12GB). Uses hindsight memory provider. Defined in `agents/hermes/`.
- **Openclaw**: Orchestrator agent (`ghcr.io/openclaw/openclaw:latest`). Manages debate flow, memory coordination, git commits, OMC↔Discord bridge, confidence scoring, Claude Code escalation. NOT a debater.
- **Lucid Memory Provider**: MCP-based associative memory (already in dotfiles via `make lucid`). Used by Nullclaw.
- **Hindsight Memory Provider**: NousResearch hermes-agent plugin (`hindsight-client`). Knowledge graph + entity resolution + multi-strategy retrieval. Local embedded mode. Used by Hermes.
- **Issue Agent**: Per-issue openclaw instance in an isolated container (no egress, scoped to project dir). Spawns freely. Distinct from Universal Observer.
- **Confidence Score**: 0–1 metric produced by openclaw after a debate round. High score (≥0.75) triggers Escalation to Claude Code. Low score keeps work in the repo agent loop.
- **Escalation**: When Confidence Score ≥ threshold, openclaw sends the issue URL to OMC → Claude Code goes fully autonomous on implementation.
- **Distillation**: Claude Code implementations committed back to the repo → repo agents learn patterns from the diff → reduces Claude Code dependency over time for repeat tasks.
- **OMC Path**: User → Claude Code (OMC hooks) → openclaw gateway → Universal Observer. Requires personal subscription, TOS-approved via hooks.
- **Standalone Path**: User → Discord direct → Universal Observer. No Claude Code required. Both paths always available.

## Relationships

- **Universal Observer** is-a **Living Code Repository** (dotfiles = first, singleton)
- **Universal Observer** manages N **Issue Agents** (1:N, cross-repo)
- **Debate** involves **Nullclaw** ↔ **Hermes** (1:1 per round)
- **Openclaw** orchestrates **Nullclaw** + **Hermes** (1:2)
- **Debate** produces **Debate Record** (1:1)
- **Debate Record** contains **Confidence Score** (1:1)
- **Nullclaw** uses **Lucid Memory Provider** (1:1)
- **Hermes** uses **Hindsight Memory Provider** (1:1)
- **Issue Agent** inherits structure from **Universal Observer** (template pattern)
- **Confidence Score** ≥ 0.75 → triggers **Escalation** → **Claude Code** implements → **Distillation**

## Example Dialogue

> **User → Universal Observer**: "Issue #42: should we use Nix or stow for dotfile management?"
>
> **Openclaw**: Routes to debate. Nullclaw argues Nix feels more intentional and expressive. Hermes argues stow is already working and adding Nix has no measurable benefit. Confidence: 0.82. Escalating to Claude Code for implementation of stow improvements.

## Flagged Ambiguities

- None currently open.
