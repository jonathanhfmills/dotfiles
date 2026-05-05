# ADR-0005: CLI Wrappers for Training-Aligned Inference

## Status
Accepted

## Context
Each local model was fine-tuned using a specific CLI tool's prompt format and RLHF loop. Using a different invocation path produces lower-quality output because the model's latent behavior is optimized for the training CLI's exact prompt structure.

## Decision
Each model uses its native training CLI for all agentic invocations:
- **Gemma 4** → `gemini -p "$prompt"` (Gemini CLI, local llama.cpp endpoint)
- **Qwen 3.5** → `qwen --print "$prompt"` (Qwen Code CLI, local llama.cpp endpoint)
- **Claude** → `claude --print "$prompt"` (Claude Code CLI, escalation path only)

For debate turns specifically, `hindsight_litellm.completion()` wraps Nullclaw (Gemma 4) and `qwen_agent.agents.Assistant` wraps Hermes (Qwen 3.5) — both route to the same llama.cpp endpoints and preserve training alignment via the native SDK.

The Gemini CLI is configured with `GEMINI_BASE_URL` pointing to local llama.cpp only. Google TOS prohibits using personal subscriptions for automated agentic turns — frontier Gemini stays on bare metal (human + OMC layer).

## Alternatives Considered
- **Generic OpenAI-compatible HTTP**: Works but bypasses training-optimized prompt templates → measurably lower coherence for Qwen 3.5 structured tasks.
- **Single universal SDK (LiteLLM only)**: Loses Hermes' MCP tool-calling and thinking mode from `qwen_agent`.

## Consequences
- `run_debate.py` depends on `hindsight-litellm` and `qwen-agent` packages
- Digital twin container must install both (`make hindsight`, `make qwen`)
- Gemini CLI hard-coded to local; switching to frontier requires bare-metal layer (deliberate)
