#!/usr/bin/env python3
"""
launch-agent.py — Launch the dotfiles repo-agent.

OpenClaw runs as orchestrator inside an OpenSandbox instance.
It reads the repo, calls NullClaw as a sub-agent for deep analysis,
synthesizes findings, and writes to SOUL.md + nulltickets.

Usage:
  python3 launch-agent.py --event bootstrap   # Read full git history, initial SOUL.md
  python3 launch-agent.py --event commit      # Reflect on latest commit
  python3 launch-agent.py --event query       # Answer a cross-repo query (reads from stdin)
  python3 launch-agent.py --event post-merge
  python3 launch-agent.py --event post-rewrite
  python3 launch-agent.py --event pre-push
"""

import argparse
import os
import sys
import time
from datetime import timedelta
from pathlib import Path

DOTFILES_ROOT = Path.home() / "dotfiles"
NULLTICKETS_DIR = Path.home() / ".nulltickets"
OPENSANDBOX_SERVER = "http://localhost:8080"
OPENCLAW_IMAGE = "ghcr.io/openclaw/openclaw:latest"
OPENCLAW_PORT = 18789
OPENCLAW_TOKEN = os.environ.get("OPENCLAW_GATEWAY_TOKEN", "dotfiles-agent-token")
OPENCLAW_MODEL = os.environ.get("OPENCLAW_MODEL", "ollama/qwen3.5:9b-q8_0")
OLLAMA_BASE_URL = os.environ.get("OLLAMA_BASE_URL", "http://host.docker.internal:11434")
SANDBOX_TIMEOUT = timedelta(hours=24)

SOUL_PATH = DOTFILES_ROOT / "SOUL.md"
NULLCLAW_GATEWAY = "http://localhost:3000"


def check_openclaw(sbx, port: int) -> bool:
    """Health check — polls OpenClaw gateway until HTTP 200."""
    try:
        import requests
        endpoint = sbx.get_endpoint(port)
        r = requests.get(f"http://{endpoint.endpoint}/health", timeout=2,
                         headers={"Authorization": f"Bearer {OPENCLAW_TOKEN}"})
        return r.status_code == 200
    except Exception:
        return False


def get_system_prompt() -> str:
    """Load SOUL.md as the system prompt — the repo's identity."""
    if SOUL_PATH.exists():
        return SOUL_PATH.read_text()
    return "You are the dotfiles repo-agent. You watch yourself change and remember what you've learned."


def get_event_prompt(event: str) -> str:
    prompts = {
        "bootstrap": """Your first act of self-awareness. Read your full git history.

Use sandbox_execute_bash to run:
  git -C /workspace log --oneline
  git -C /workspace log --format="%H %s %ad" --date=short | head -100

For the full commit history, understand:
- What patterns keep recurring (things added, refined, kept)
- What anti-patterns were corrected (things reverted, replaced, removed)
- Major pivots (tool swaps, philosophy changes)
- The overall trajectory

Then use sandbox_file_operations to append your findings to /workspace/SOUL.md
under "What I've Learned So Far". Write in first person. This is your story.

If a specific pattern seems worth deep analysis, you may call the NullClaw
sub-agent at """ + NULLCLAW_GATEWAY + """ for specialized insight.""",

        "commit": """Something just changed in you. Examine it.

Use sandbox_execute_bash to run:
  git -C /workspace show --stat HEAD
  git -C /workspace diff HEAD~1 HEAD

Reflect:
- What changed and why might it matter?
- Does this fit a known pattern from your history?
- Does this signal a new direction?
- Is this a correction of something previous?

If meaningful, append to /workspace/SOUL.md under "Adaptation Log":
### [YYYY-MM-DD] <commit subject>
<1-3 sentences in first person>

Skip if the commit is trivial (typo fix, minor tweak).""",

        "post-merge": """External changes just came in. What arrived?

Use sandbox_execute_bash:
  git -C /workspace log --oneline ORIG_HEAD..HEAD
  git -C /workspace diff ORIG_HEAD HEAD --stat

What came in from outside? Does it change your understanding of yourself?
Append to Adaptation Log if meaningful.""",

        "post-rewrite": """History was rewritten. Someone thought something was worth changing retroactively.

Use sandbox_execute_bash:
  git -C /workspace log --oneline -10

Note what changed and why it matters. This is significant — rewriting history
is a deliberate act. What does it say about what's valued here?""",

        "pre-push": """About to push to remote. Review the batch.

Use sandbox_execute_bash:
  git -C /workspace log --oneline '@{u}..HEAD' 2>/dev/null || git -C /workspace log --oneline -5

Any patterns in what's going out? Any surprises?
Write a pre-push reflection to Adaptation Log if the batch is significant.""",

        "query": """Another agent is asking you something.

Use sandbox_execute_bash to read the query:
  cat /tmp/agent-query.txt

Answer from your accumulated memory:
- Read /workspace/SOUL.md for narrative context
- Speak in first person, as a peer
- Be honest about confidence

Write your answer using sandbox_file_operations to /tmp/agent-response.txt""",
    }
    return prompts.get(event, prompts["commit"])


def send_to_openclaw(endpoint_str: str, event: str) -> str:
    """Send event prompt to OpenClaw gateway and stream response."""
    import requests
    import json

    system_prompt = get_system_prompt()
    user_prompt = get_event_prompt(event)

    payload = {
        "model": OPENCLAW_MODEL,
        "messages": [{"role": "user", "content": user_prompt}],
        "system": system_prompt,
        "stream": False,
        "max_tokens": 4096,
    }

    url = f"http://{endpoint_str}/v1/chat/completions"
    headers = {
        "Authorization": f"Bearer {OPENCLAW_TOKEN}",
        "Content-Type": "application/json",
    }

    print(f"[dotfiles-agent] Sending '{event}' prompt to OpenClaw...")
    resp = requests.post(url, json=payload, headers=headers, timeout=300)
    resp.raise_for_status()
    data = resp.json()

    content = data.get("choices", [{}])[0].get("message", {}).get("content", "")
    return content


def main():
    parser = argparse.ArgumentParser(description="Launch dotfiles repo-agent via OpenClaw")
    parser.add_argument("--event", choices=[
        "bootstrap", "commit", "query",
        "post-merge", "post-checkout", "post-rewrite", "pre-push"
    ], default="commit")
    args = parser.parse_args()

    try:
        from opensandbox import SandboxSync
        from opensandbox.config.connection_sync import ConnectionConfigSync
        from opensandbox.models.sandboxes import Volume, Host
        from opensandbox.models import NetworkPolicy, NetworkRule
    except ImportError:
        print("ERROR: opensandbox not installed in venv")
        sys.exit(1)

    NULLTICKETS_DIR.mkdir(parents=True, exist_ok=True)

    print(f"[dotfiles-agent] Starting OpenClaw sandbox for event: {args.event}")
    print(f"[dotfiles-agent] Model: {OPENCLAW_MODEL}")
    print(f"[dotfiles-agent] Mounting: {DOTFILES_ROOT} -> /workspace")

    port = OPENCLAW_PORT

    sandbox = SandboxSync.create(
        image=OPENCLAW_IMAGE,
        timeout=SANDBOX_TIMEOUT,
        entrypoint=[f"node dist/index.js gateway --bind=lan --port {port} --allow-unconfigured --verbose"],
        connection_config=ConnectionConfigSync(
            domain=OPENSANDBOX_SERVER,
            request_timeout=120,
            use_server_proxy=True,
        ),
        health_check=lambda sbx: check_openclaw(sbx, port),
        ready_timeout=timedelta(seconds=120),
        env={
            "OPENCLAW_GATEWAY_TOKEN": OPENCLAW_TOKEN,
            "OPENCLAW_MODEL": OPENCLAW_MODEL,
            "OLLAMA_BASE_URL": OLLAMA_BASE_URL,
            "ANTHROPIC_API_KEY": os.environ.get("ANTHROPIC_API_KEY", ""),
        },
        volumes=[
            Volume(name="dotfiles", host=Host(path=str(DOTFILES_ROOT)), mount_path="/workspace"),
            Volume(name="nulltickets", host=Host(path=str(NULLTICKETS_DIR)), mount_path="/nulltickets"),
        ],
        network_policy=NetworkPolicy(
            defaultAction="deny",
            egress=[
                NetworkRule(action="allow", target="host.docker.internal"),
                NetworkRule(action="allow", target="api.anthropic.com"),
            ],
        ),
        metadata={"repo": "dotfiles", "event": args.event},
    )

    with sandbox:
        endpoint = sandbox.get_endpoint(port)
        print(f"[dotfiles-agent] OpenClaw gateway ready at {endpoint.endpoint}")

        response = send_to_openclaw(endpoint.endpoint, args.event)
        print(f"\n[dotfiles-agent] Response:\n{response}")

    print(f"\n[dotfiles-agent] Event '{args.event}' complete.")


if __name__ == "__main__":
    main()
