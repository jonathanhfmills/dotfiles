#!/usr/bin/env python3
"""MCP Server: Task Dispatch — routes tasks to agents across the fleet via OpenSandbox API.

Exposes MCP tools over stdio (JSON-RPC 2.0):
  - dispatch_task(agent, prompt, labels) → sends task to target host's queue
  - list_agents() → returns available agents and their hosts
  - get_task_status(task_id) → checks task completion status
"""
import json
import os
import sys
import time
import uuid


# Host routing — which agents run where
AGENT_HOSTS = {
    # NAS agents (wanda)
    "writer": "nas",
    "reader": "nas",
    # Workstation agents (cosmo)
    "cosmo": "workstation",
    "coder": "workstation",
    "reviewer": "workstation",
    "deployer": "workstation",
}

# Queue base path (Syncthing-synced between hosts)
QUEUE_BASE = os.environ.get("QUEUE_BASE", "/var/lib/orchestrator/shared/queue")
RESULTS_DIR = os.path.join(QUEUE_BASE, "results")


def dispatch_task(agent: str, prompt: str, labels: list[str] | None = None) -> dict:
    """Submit a task to the appropriate host queue for execution."""
    if agent not in AGENT_HOSTS:
        return {"error": f"Unknown agent: {agent}. Available: {list(AGENT_HOSTS.keys())}"}

    host = AGENT_HOSTS[agent]
    task_id = f"{agent}-{uuid.uuid4().hex[:8]}"
    queue_dir = os.path.join(QUEUE_BASE, host)

    task = {
        "id": task_id,
        "agent": agent,
        "prompt": prompt,
        "labels": labels or [],
        "submitted_at": time.time(),
        "host": host,
    }

    # Atomic write: write to /tmp then mv (inotifywait triggers on CREATE before content)
    tmp_path = f"/tmp/{task_id}.json"
    dest_path = os.path.join(queue_dir, f"{task_id}.json")

    os.makedirs(queue_dir, exist_ok=True)
    with open(tmp_path, "w") as f:
        json.dump(task, f, indent=2)
    os.rename(tmp_path, dest_path)

    return {"task_id": task_id, "host": host, "agent": agent, "status": "queued"}


def list_agents() -> dict:
    """List available agents and their host assignments."""
    return {
        "agents": [
            {"id": agent, "host": host}
            for agent, host in AGENT_HOSTS.items()
        ]
    }


def get_task_status(task_id: str) -> dict:
    """Check if a task has completed."""
    done_path = os.path.join(RESULTS_DIR, f"{task_id}.done.json")
    error_path = os.path.join(RESULTS_DIR, f"{task_id}.error.json")
    result_dir = os.path.join(RESULTS_DIR, task_id)

    if os.path.exists(done_path):
        return {"task_id": task_id, "status": "completed", "result_dir": result_dir}
    elif os.path.exists(error_path):
        return {"task_id": task_id, "status": "error"}
    else:
        return {"task_id": task_id, "status": "pending"}


# MCP tool definitions
TOOLS = [
    {
        "name": "dispatch_task",
        "description": "Submit a task to an agent on the appropriate host for execution",
        "inputSchema": {
            "type": "object",
            "properties": {
                "agent": {
                    "type": "string",
                    "description": "Agent ID (cosmo, coder, reviewer, deployer, writer, reader)",
                },
                "prompt": {
                    "type": "string",
                    "description": "The task prompt/instructions for the agent",
                },
                "labels": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Optional labels for task categorization",
                },
            },
            "required": ["agent", "prompt"],
        },
    },
    {
        "name": "list_agents",
        "description": "List all available agents and their host assignments",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "get_task_status",
        "description": "Check the completion status of a previously dispatched task",
        "inputSchema": {
            "type": "object",
            "properties": {
                "task_id": {
                    "type": "string",
                    "description": "The task ID returned by dispatch_task",
                },
            },
            "required": ["task_id"],
        },
    },
]


def handle_request(request: dict) -> dict:
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
                "serverInfo": {"name": "dispatch", "version": "0.1.0"},
            },
        }
    elif method == "tools/list":
        return {"jsonrpc": "2.0", "id": req_id, "result": {"tools": TOOLS}}
    elif method == "tools/call":
        tool_name = params.get("name", "")
        args = params.get("arguments", {})

        if tool_name == "dispatch_task":
            result = dispatch_task(**args)
        elif tool_name == "list_agents":
            result = list_agents()
        elif tool_name == "get_task_status":
            result = get_task_status(**args)
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
        return None  # No response for notifications
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
