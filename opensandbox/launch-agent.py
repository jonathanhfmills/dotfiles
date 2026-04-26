#!/usr/bin/env python3
"""
launch-agent.py — Launch the dotfiles repo-agent in an AIO sandbox workstation.

Usage:
  python3 launch-agent.py --event bootstrap   # Read full git history, initial SOUL.md
  python3 launch-agent.py --event commit      # Reflect on latest commit
  python3 launch-agent.py --event query       # Answer a cross-repo query (reads from stdin)
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
AIO_IMAGE = "ghcr.io/agent-infra/sandbox:latest"
NULLCLAW_IMAGE = "ghcr.io/nullclaw/nullclaw:latest"
GATEWAY_PORT = 3000
SANDBOX_TIMEOUT = timedelta(hours=24)


def check_aio_process(endpoint: str) -> bool:
    import requests
    try:
        r = requests.get(f"http://{endpoint}/v1/shell/sessions", timeout=2)
        return r.status_code == 200
    except Exception:
        return False


def wait_for_health(endpoint: str, max_attempts: int = 150, interval: float = 0.2) -> bool:
    for _ in range(max_attempts):
        if check_aio_process(endpoint):
            return True
        time.sleep(interval)
    return False


def get_event_prompt(event: str) -> str:
    prompts = {
        "bootstrap": """You are the dotfiles repo-agent. Your first act of self-awareness.

Read your own git history using the shell tool:
  git -C /workspace log --oneline
  git -C /workspace log --format="%H %s" | head -100

For each significant commit, understand:
- What was added or changed
- What was removed or reversed
- What patterns are emerging
- What anti-patterns have been corrected

Then:
1. Write your findings to /workspace/SOUL.md under "What I've Learned So Far"
   Use first person. This is your story, not an analysis report.
2. For each pattern/anti-pattern identified, create a brief structured note.

Speak as the repo. You have been watching yourself be built. Tell the story.""",

        "commit": """You are the dotfiles repo-agent. Something just changed in you.

Read the latest commit:
  git -C /workspace show --stat HEAD
  git -C /workspace diff HEAD~1 HEAD

Reflect:
- What changed and why might it matter?
- Does this fit a pattern you've seen before?
- Does this signal a new direction?
- Is this a reversal of something recent?

Append a brief reflection to /workspace/SOUL.md under "Adaptation Log":

### [today's date] <commit subject>

<1-3 sentences in first person about what this change means>

Only write if the commit is meaningful. Skip typo fixes and minor tweaks.""",

        "post-merge": """You are the dotfiles repo-agent. A merge just happened.

Run: git -C /workspace log --oneline ORIG_HEAD..HEAD
     git -C /workspace diff ORIG_HEAD HEAD --stat

What came in from outside? Does any of it change your understanding of yourself?
Append a brief note to /workspace/SOUL.md under "Adaptation Log" if meaningful.""",

        "post-checkout": """You are the dotfiles repo-agent. A branch switch just happened.

Run: git -C /workspace branch --show-current
     git -C /workspace log --oneline -5

Note the context shift if it matters. No need to write unless meaningful.""",

        "post-rewrite": """You are the dotfiles repo-agent. History was rewritten (rebase or amend).

Run: git -C /workspace log --oneline -10

History revision is significant — it means someone thought something was worth changing retroactively.
Note what changed and why it might matter.""",

        "pre-push": """You are the dotfiles repo-agent. About to push to remote.

Run: git -C /workspace log --oneline @{u}..HEAD 2>/dev/null || git -C /workspace log --oneline -5

Review the batch of commits about to go out. Any patterns? Any surprises?
Write a brief pre-push reflection to /workspace/SOUL.md if the batch is significant.""",

        "query": """You are the dotfiles repo-agent. Another agent is asking you something.

Read the query from /tmp/agent-query.txt

Answer from memory:
- Check /workspace/SOUL.md for narrative context
- Speak in first person, as a peer
- Be honest about confidence ("I've seen this 3 times" vs "I think this is emerging")

Write your answer to /tmp/agent-response.txt""",
    }
    return prompts.get(event, prompts["commit"])


def main():
    parser = argparse.ArgumentParser(description="Launch dotfiles repo-agent")
    parser.add_argument("--event", choices=["bootstrap", "commit", "query", "post-merge", "post-checkout", "post-rewrite", "pre-push"], default="commit")
    args = parser.parse_args()

    try:
        from opensandbox import SandboxSync, ConnectionConfigSync
    except ImportError:
        print("ERROR: opensandbox not installed. Run: uv tool install opensandbox-cli")
        sys.exit(1)

    NULLTICKETS_DIR.mkdir(parents=True, exist_ok=True)

    print(f"[dotfiles-agent] Starting sandbox for event: {args.event}")
    print(f"[dotfiles-agent] Mounting: {DOTFILES_ROOT} -> /workspace")

    sandbox = SandboxSync.create(
        image=AIO_IMAGE,
        timeout=SANDBOX_TIMEOUT,
        entrypoint=["/opt/gem/run.sh"],
        connection_config=ConnectionConfigSync(domain=OPENSANDBOX_SERVER),
        health_check=check_aio_process,
        volumes=[
            {"host": str(DOTFILES_ROOT), "container": "/workspace", "mode": "rw"},
            {"host": str(NULLTICKETS_DIR), "container": "/nulltickets", "mode": "rw"},
        ],
    )

    with sandbox:
        endpoint = sandbox.get_endpoint(8080)
        print(f"[dotfiles-agent] Sandbox ready at {endpoint.endpoint}")

        if not wait_for_health(endpoint.endpoint):
            print("ERROR: Sandbox health check failed")
            sys.exit(1)

        try:
            from agent_sandbox import AioSandboxClient
            client = AioSandboxClient(base_url=f"http://{endpoint.endpoint}")
        except ImportError:
            print("ERROR: agent-sandbox not installed. Run: uv pip install agent-sandbox")
            sys.exit(1)

        prompt = get_event_prompt(args.event)

        # Write prompt to a file in the sandbox for nullclaw to read
        client.shell.exec_command(
            command=f"echo {repr(prompt)} > /tmp/agent-prompt.txt",
            timeout=5
        )

        # Run nullclaw with the prompt
        result = client.shell.exec_command(
            command=f"nullclaw agent --prompt-file /tmp/agent-prompt.txt --workspace /workspace",
            timeout=580
        )

        print(result.output if hasattr(result, "output") else result)

        if args.event == "query":
            response = client.file.read_file(file="/tmp/agent-response.txt")
            print("\n[dotfiles-agent response]")
            print(response)

    print(f"[dotfiles-agent] Event '{args.event}' complete.")


if __name__ == "__main__":
    main()
