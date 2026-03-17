#!/usr/bin/env python3
"""MCP Server: Sandbox — spawn and manage child sandboxes via OpenSandbox API.

Exposes MCP tools over stdio (JSON-RPC 2.0):
  - spawn_sandbox(type, timeout) → create a child sandbox
  - exec_in_sandbox(sandbox_id, command) → run a command inside a sandbox
  - read_sandbox_file(sandbox_id, path) → read a file from sandbox filesystem
  - write_sandbox_file(sandbox_id, path, content) → write a file into sandbox
  - get_sandbox_endpoints(sandbox_id) → get exposed ports
  - kill_sandbox(sandbox_id) → terminate and cleanup
"""
import json
import os
import sys
import threading
import time
import urllib.request
import urllib.error

OPENSANDBOX_URL = os.environ.get("OPENSANDBOX_URL", "http://172.17.0.1:8080")
AGENT_NAME = os.environ.get("AGENT_NAME", "unknown")

# Sandbox type → image + resource limits + exposed ports
SANDBOX_TYPES = {
    "code-interpreter": {
        "image": "opensandbox/code-interpreter:v1.0.2",
        "cpu": "500m",
        "memory": "1Gi",
        "ports": [],
    },
    "playwright": {
        "image": "opensandbox/playwright:latest",
        "cpu": "500m",
        "memory": "1Gi",
        "ports": [],
    },
    "chrome": {
        "image": "opensandbox/chrome:latest",
        "cpu": "1000m",
        "memory": "2Gi",
        "ports": [5901, 9222],
    },
    "desktop": {
        "image": "opensandbox/desktop:latest",
        "cpu": "1000m",
        "memory": "2Gi",
        "ports": [5901, 6080],
    },
    "vscode": {
        "image": "opensandbox/vscode:latest",
        "cpu": "500m",
        "memory": "1Gi",
        "ports": [8080],
    },
    "aio": {
        "image": "ghcr.io/agent-infra/sandbox:latest",
        "cpu": "1000m",
        "memory": "2Gi",
        "ports": [8080],
    },
}

# Per-agent allowlist — which agents can spawn which sandbox types
AGENT_ALLOWLIST = {
    "coder": ["code-interpreter", "vscode", "aio"],
    "reviewer": ["code-interpreter"],
    "reader": ["playwright", "chrome"],
    "writer": ["aio"],
    "deployer": ["desktop", "chrome"],
    "cosmo": ["code-interpreter", "vscode", "aio", "playwright", "chrome", "desktop"],
}

# Default max TTL for child sandboxes (seconds)
DEFAULT_TTL = 600
MAX_TTL = 1800

# Track active sandboxes for TTL reaping
_active_sandboxes: dict[str, float] = {}  # sandbox_id → expiry timestamp
_reaper_started = False


def _api_call(method: str, path: str, body: dict | None = None) -> dict:
    """Make an HTTP request to the OpenSandbox API."""
    url = f"{OPENSANDBOX_URL}{path}"
    data = json.dumps(body).encode() if body else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        body_text = e.read().decode() if e.fp else ""
        return {"error": f"HTTP {e.code}: {body_text}"}
    except urllib.error.URLError as e:
        return {"error": f"Connection failed: {e.reason}"}


def _start_reaper():
    """Start background thread that kills expired sandboxes."""
    global _reaper_started
    if _reaper_started:
        return
    _reaper_started = True

    def reaper():
        while True:
            time.sleep(30)
            now = time.time()
            expired = [sid for sid, exp in _active_sandboxes.items() if now >= exp]
            for sid in expired:
                _api_call("DELETE", f"/v1/sandboxes/{sid}")
                _active_sandboxes.pop(sid, None)

    t = threading.Thread(target=reaper, daemon=True)
    t.start()


def spawn_sandbox(type: str, timeout: int | None = None) -> dict:
    """Create a child sandbox of the given type."""
    if type not in SANDBOX_TYPES:
        return {"error": f"Unknown sandbox type: {type}. Available: {list(SANDBOX_TYPES.keys())}"}

    allowed = AGENT_ALLOWLIST.get(AGENT_NAME, [])
    if AGENT_NAME != "unknown" and type not in allowed:
        return {"error": f"Agent '{AGENT_NAME}' not allowed to spawn '{type}'. Allowed: {allowed}"}

    spec = SANDBOX_TYPES[type]
    ttl = min(timeout or DEFAULT_TTL, MAX_TTL)

    result = _api_call("POST", "/v1/sandboxes", {
        "image": {"uri": spec["image"]},
        "timeout": ttl,
        "resourceLimits": {"cpu": spec["cpu"], "memory": spec["memory"]},
        "networkPolicy": {
            "defaultAction": "deny",
            "egress": [],
        },
    })

    if "error" in result:
        return result

    sandbox_id = result.get("id")
    if not sandbox_id:
        return {"error": "No sandbox ID returned", "response": result}

    _active_sandboxes[sandbox_id] = time.time() + ttl
    _start_reaper()

    return {
        "sandbox_id": sandbox_id,
        "type": type,
        "image": spec["image"],
        "ttl": ttl,
        "ports": spec["ports"],
    }


def exec_in_sandbox(sandbox_id: str, command: str) -> dict:
    """Run a command inside a sandbox."""
    if sandbox_id not in _active_sandboxes:
        return {"error": f"Unknown sandbox: {sandbox_id}"}

    result = _api_call("POST", f"/v1/sandboxes/{sandbox_id}/exec", {
        "command": ["sh", "-c", command],
    })
    return result


def read_sandbox_file(sandbox_id: str, path: str) -> dict:
    """Read a file from sandbox filesystem."""
    if sandbox_id not in _active_sandboxes:
        return {"error": f"Unknown sandbox: {sandbox_id}"}

    result = _api_call("GET", f"/v1/sandboxes/{sandbox_id}/files?path={path}")
    return result


def write_sandbox_file(sandbox_id: str, path: str, content: str) -> dict:
    """Write a file into sandbox."""
    if sandbox_id not in _active_sandboxes:
        return {"error": f"Unknown sandbox: {sandbox_id}"}

    result = _api_call("POST", f"/v1/sandboxes/{sandbox_id}/files", {
        "path": path,
        "content": content,
    })
    return result


def get_sandbox_endpoints(sandbox_id: str) -> dict:
    """Get exposed ports and endpoints for a sandbox."""
    if sandbox_id not in _active_sandboxes:
        return {"error": f"Unknown sandbox: {sandbox_id}"}

    result = _api_call("GET", f"/v1/sandboxes/{sandbox_id}")
    if "error" in result:
        return result

    return {
        "sandbox_id": sandbox_id,
        "status": result.get("status", {}),
        "ports": result.get("ports", []),
    }


def kill_sandbox(sandbox_id: str) -> dict:
    """Terminate and cleanup a sandbox."""
    if sandbox_id not in _active_sandboxes:
        return {"error": f"Unknown sandbox: {sandbox_id}"}

    result = _api_call("DELETE", f"/v1/sandboxes/{sandbox_id}")
    _active_sandboxes.pop(sandbox_id, None)

    if "error" in result:
        return result

    return {"sandbox_id": sandbox_id, "status": "terminated"}


# MCP tool definitions
TOOLS = [
    {
        "name": "spawn_sandbox",
        "description": "Create a child sandbox (code-interpreter, playwright, chrome, desktop, vscode, aio)",
        "inputSchema": {
            "type": "object",
            "properties": {
                "type": {
                    "type": "string",
                    "enum": list(SANDBOX_TYPES.keys()),
                    "description": "Sandbox type to spawn",
                },
                "timeout": {
                    "type": "integer",
                    "description": f"TTL in seconds (default {DEFAULT_TTL}, max {MAX_TTL})",
                },
            },
            "required": ["type"],
        },
    },
    {
        "name": "exec_in_sandbox",
        "description": "Run a shell command inside a sandbox and return stdout/stderr",
        "inputSchema": {
            "type": "object",
            "properties": {
                "sandbox_id": {"type": "string", "description": "Sandbox ID from spawn_sandbox"},
                "command": {"type": "string", "description": "Shell command to execute"},
            },
            "required": ["sandbox_id", "command"],
        },
    },
    {
        "name": "read_sandbox_file",
        "description": "Read a file from a sandbox filesystem",
        "inputSchema": {
            "type": "object",
            "properties": {
                "sandbox_id": {"type": "string", "description": "Sandbox ID"},
                "path": {"type": "string", "description": "Absolute path inside the sandbox"},
            },
            "required": ["sandbox_id", "path"],
        },
    },
    {
        "name": "write_sandbox_file",
        "description": "Write content to a file inside a sandbox",
        "inputSchema": {
            "type": "object",
            "properties": {
                "sandbox_id": {"type": "string", "description": "Sandbox ID"},
                "path": {"type": "string", "description": "Absolute path inside the sandbox"},
                "content": {"type": "string", "description": "File content to write"},
            },
            "required": ["sandbox_id", "path", "content"],
        },
    },
    {
        "name": "get_sandbox_endpoints",
        "description": "Get exposed ports and connection info for a sandbox (VNC, DevTools, etc.)",
        "inputSchema": {
            "type": "object",
            "properties": {
                "sandbox_id": {"type": "string", "description": "Sandbox ID"},
            },
            "required": ["sandbox_id"],
        },
    },
    {
        "name": "kill_sandbox",
        "description": "Terminate a sandbox and free its resources",
        "inputSchema": {
            "type": "object",
            "properties": {
                "sandbox_id": {"type": "string", "description": "Sandbox ID"},
            },
            "required": ["sandbox_id"],
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
                "serverInfo": {"name": "sandbox", "version": "0.1.0"},
            },
        }
    elif method == "tools/list":
        return {"jsonrpc": "2.0", "id": req_id, "result": {"tools": TOOLS}}
    elif method == "tools/call":
        tool_name = params.get("name", "")
        args = params.get("arguments", {})

        if tool_name == "spawn_sandbox":
            result = spawn_sandbox(**args)
        elif tool_name == "exec_in_sandbox":
            result = exec_in_sandbox(**args)
        elif tool_name == "read_sandbox_file":
            result = read_sandbox_file(**args)
        elif tool_name == "write_sandbox_file":
            result = write_sandbox_file(**args)
        elif tool_name == "get_sandbox_endpoints":
            result = get_sandbox_endpoints(**args)
        elif tool_name == "kill_sandbox":
            result = kill_sandbox(**args)
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
