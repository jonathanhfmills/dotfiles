#!/usr/bin/env python3
"""MCP Server: Escalation — tier promotion and trajectory evaluation.

Exposes MCP tools over stdio (JSON-RPC 2.0):
  - escalate(task_id, reason) → promotes task to next tier per escalation.yaml
  - evaluate_quality(task_id, trajectory) → scores via MoE evaluator (35B-A3B)
  - get_promotion_chain(category) → returns the tier chain for a task category
"""
import json
import os
import sys
import time

import urllib.request


# Inference endpoints
EVALUATOR_URL = os.environ.get("EVALUATOR_URL", "http://wanda:11435/v1")
EVALUATOR_MODEL = os.environ.get("EVALUATOR_MODEL", "Qwen/Qwen3.5-35B-A3B")
EVALUATOR_API_KEY = os.environ.get("EVALUATOR_API_KEY", "ollama")

# Escalation log
ESCALATION_LOG_DIR = os.environ.get(
    "ESCALATION_LOG_DIR", "/var/lib/orchestrator/shared/escalation-log"
)

# Promotion chains (matches escalation.yaml)
PROMOTION_CHAINS = {
    "coding": [
        {"model": "Qwen/Qwen3.5-4B", "endpoint": "http://cosmo:11434/v1"},
        {"model": "Qwen/Qwen3.5-9B", "endpoint": "http://wanda:11434/v1"},
        {"model": "Qwen/Qwen3.5-35B-A3B", "endpoint": "http://wanda:11435/v1", "scorer_only": True},
        {"model": "qwen/qwen3.5-397b-a17b", "endpoint": "https://openrouter.ai/api/v1"},
        {"model": "claude-opus", "endpoint": "https://openrouter.ai/api/v1"},
    ],
    "code_review": [
        {"model": "Qwen/Qwen3.5-4B", "endpoint": "http://cosmo:11434/v1"},
        {"model": "Qwen/Qwen3.5-9B", "endpoint": "http://wanda:11434/v1"},
        {"model": "Qwen/Qwen3.5-35B-A3B", "endpoint": "http://wanda:11435/v1", "scorer_only": True},
        {"model": "qwen/qwen3.5-397b-a17b", "endpoint": "https://openrouter.ai/api/v1"},
        {"model": "claude-opus", "endpoint": "https://openrouter.ai/api/v1"},
    ],
    "writing": [
        {"model": "Qwen/Qwen3.5-9B", "endpoint": "http://wanda:11434/v1"},
        {"model": "Qwen/Qwen3.5-35B-A3B", "endpoint": "http://wanda:11435/v1", "scorer_only": True},
        {"model": "qwen/qwen3.5-397b-a17b", "endpoint": "https://openrouter.ai/api/v1"},
        {"model": "claude-opus", "endpoint": "https://openrouter.ai/api/v1"},
    ],
    "research": [
        {"model": "Qwen/Qwen3.5-9B", "endpoint": "http://wanda:11434/v1"},
        {"model": "Qwen/Qwen3.5-35B-A3B", "endpoint": "http://wanda:11435/v1", "scorer_only": True},
        {"model": "qwen/qwen3.5-397b-a17b", "endpoint": "https://openrouter.ai/api/v1"},
        {"model": "claude-opus", "endpoint": "https://openrouter.ai/api/v1"},
    ],
}


def escalate(task_id: str, reason: str, category: str = "coding", current_tier: int = 0) -> dict:
    """Promote a task to the next tier in its promotion chain."""
    chain = PROMOTION_CHAINS.get(category)
    if not chain:
        return {"error": f"Unknown category: {category}"}

    next_tier = current_tier + 1
    # Skip scorer-only tiers for task execution
    while next_tier < len(chain) and chain[next_tier].get("scorer_only"):
        next_tier += 1

    if next_tier >= len(chain):
        return {"error": "No more tiers available", "task_id": task_id}

    target = chain[next_tier]

    # Log escalation
    log_dir = os.path.join(ESCALATION_LOG_DIR, category)
    os.makedirs(log_dir, exist_ok=True)
    log_entry = {
        "task_id": task_id,
        "reason": reason,
        "from_tier": current_tier,
        "to_tier": next_tier,
        "target_model": target["model"],
        "target_endpoint": target["endpoint"],
        "timestamp": time.time(),
    }
    with open(os.path.join(log_dir, f"{task_id}.json"), "w") as f:
        json.dump(log_entry, f, indent=2)

    return {
        "task_id": task_id,
        "escalated_to": target["model"],
        "endpoint": target["endpoint"],
        "tier": next_tier,
        "status": "escalated",
    }


def evaluate_quality(task_id: str, trajectory: str) -> dict:
    """Score a trajectory using the MoE evaluator (35B-A3B on NAS CPU).

    Returns a score from 0-10 indicating trajectory quality.
    Used as reward/punishment signal for RL training.
    """
    prompt = f"""Score the following agent trajectory on a scale of 0-10.

Criteria:
- Task completion (did it finish the requested work?)
- Efficiency (minimal unnecessary steps?)
- Tool usage (appropriate tools selected?)
- Output quality (correct, well-formatted result?)

Respond with ONLY a JSON object: {{"score": <number>, "reason": "<brief explanation>"}}

Trajectory:
{trajectory}"""

    try:
        request_body = json.dumps({
            "model": EVALUATOR_MODEL,
            "messages": [{"role": "user", "content": prompt}],
            "temperature": 0.1,
            "max_tokens": 200,
        }).encode()

        req = urllib.request.Request(
            f"{EVALUATOR_URL}/chat/completions",
            data=request_body,
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {EVALUATOR_API_KEY}",
            },
        )

        with urllib.request.urlopen(req, timeout=120) as resp:
            result = json.loads(resp.read())
            content = result["choices"][0]["message"]["content"]
            # Try to parse the score from the response
            try:
                parsed = json.loads(content)
                score = float(parsed.get("score", 0))
                reason = parsed.get("reason", "")
            except (json.JSONDecodeError, ValueError):
                score = 0.0
                reason = f"Failed to parse evaluator response: {content[:200]}"

        return {
            "task_id": task_id,
            "score": score,
            "reason": reason,
            "evaluator": EVALUATOR_MODEL,
        }
    except Exception as e:
        return {
            "task_id": task_id,
            "score": 0.0,
            "reason": f"Evaluator error: {str(e)}",
            "evaluator": EVALUATOR_MODEL,
        }


def get_promotion_chain(category: str) -> dict:
    """Return the promotion chain for a task category."""
    chain = PROMOTION_CHAINS.get(category)
    if not chain:
        return {"error": f"Unknown category: {category}. Available: {list(PROMOTION_CHAINS.keys())}"}
    return {"category": category, "chain": chain}


# MCP tool definitions
TOOLS = [
    {
        "name": "escalate",
        "description": "Promote a task to the next tier in its escalation chain",
        "inputSchema": {
            "type": "object",
            "properties": {
                "task_id": {"type": "string", "description": "The task ID to escalate"},
                "reason": {"type": "string", "description": "Why the task needs escalation"},
                "category": {
                    "type": "string",
                    "enum": ["coding", "code_review", "writing", "research"],
                    "description": "Task category (determines promotion chain)",
                },
                "current_tier": {
                    "type": "integer",
                    "description": "Current tier index (0-based)",
                    "default": 0,
                },
            },
            "required": ["task_id", "reason"],
        },
    },
    {
        "name": "evaluate_quality",
        "description": "Score a trajectory using the MoE evaluator for RL training reward signal",
        "inputSchema": {
            "type": "object",
            "properties": {
                "task_id": {"type": "string", "description": "The task ID being evaluated"},
                "trajectory": {
                    "type": "string",
                    "description": "The full agent trajectory (tool calls + observations) as text",
                },
            },
            "required": ["task_id", "trajectory"],
        },
    },
    {
        "name": "get_promotion_chain",
        "description": "Get the escalation tier chain for a task category",
        "inputSchema": {
            "type": "object",
            "properties": {
                "category": {
                    "type": "string",
                    "enum": ["coding", "code_review", "writing", "research"],
                    "description": "Task category",
                },
            },
            "required": ["category"],
        },
    },
]


def handle_request(request: dict) -> dict | None:
    """Handle a JSON-RPC 2.0 request."""
    method = request.get("method", "")
    req_id = request.get("id")
    params = request.get("params", {})

    if method == "initialize":
        return {
            "jsonrpc": "2.0",
            "id": req_id,
            "result": {
                "protocolVersion": "2024-11-05",
                "capabilities": {"tools": {"listChanged": False}},
                "serverInfo": {"name": "escalation", "version": "0.1.0"},
            },
        }
    elif method == "tools/list":
        return {"jsonrpc": "2.0", "id": req_id, "result": {"tools": TOOLS}}
    elif method == "tools/call":
        tool_name = params.get("name", "")
        args = params.get("arguments", {})

        if tool_name == "escalate":
            result = escalate(**args)
        elif tool_name == "evaluate_quality":
            result = evaluate_quality(**args)
        elif tool_name == "get_promotion_chain":
            result = get_promotion_chain(**args)
        else:
            return {
                "jsonrpc": "2.0",
                "id": req_id,
                "error": {"code": -32601, "message": f"Unknown tool: {tool_name}"},
            }

        return {
            "jsonrpc": "2.0",
            "id": req_id,
            "result": {
                "content": [{"type": "text", "text": json.dumps(result, indent=2)}]
            },
        }
    elif method == "notifications/initialized":
        return None
    else:
        return {
            "jsonrpc": "2.0",
            "id": req_id,
            "error": {"code": -32601, "message": f"Unknown method: {method}"},
        }


def main():
    """MCP server main loop — reads JSON-RPC from stdin, writes to stdout."""
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            request = json.loads(line)
            response = handle_request(request)
            if response is not None:
                sys.stdout.write(json.dumps(response) + "\n")
                sys.stdout.flush()
        except json.JSONDecodeError:
            err = {
                "jsonrpc": "2.0",
                "id": None,
                "error": {"code": -32700, "message": "Parse error"},
            }
            sys.stdout.write(json.dumps(err) + "\n")
            sys.stdout.flush()


if __name__ == "__main__":
    main()
