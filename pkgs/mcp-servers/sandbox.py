#!/usr/bin/env python3
"""MCP Server: Sandbox — spawn and manage child sandboxes via ROCK SDK.

Exposes MCP tools over stdio (JSON-RPC 2.0):
  - spawn_sandbox(type, timeout) → create a child sandbox
  - exec_in_sandbox(sandbox_id, command) → run a command inside a sandbox
  - read_sandbox_file(sandbox_id, path) → read a file from sandbox filesystem
  - write_sandbox_file(sandbox_id, path, content) → write a file into sandbox
  - get_sandbox_endpoints(sandbox_id) → get exposed ports
  - kill_sandbox(sandbox_id) → terminate and cleanup

ROCK_ENVHUB_BASE_URL must point to the ROCK Admin server (default localhost:8081).
"""
import asyncio
import json
import os
import sys
import threading
import time

AGENT_NAME = os.environ.get("AGENT_NAME", "unknown")

# Sandbox type → image + runtime config
SANDBOX_TYPES = {
    "code-interpreter": {
        "image": "python:3.11",
        "runtime": "python",
        "pip": ["ipython", "numpy", "pandas"],
    },
    "playwright": {
        "image": "mcr.microsoft.com/playwright/python:v1.43.0-jammy",
        "runtime": "python",
        "pip": ["playwright"],
    },
    "node": {
        "image": "node:20-slim",
        "runtime": "node",
        "pip": [],
    },
    "vscode": {
        "image": "python:3.11",
        "runtime": "python",
        "pip": [],
    },
    "aio": {
        "image": "python:3.11",
        "runtime": "python",
        "pip": [],
    },
}

# Per-agent allowlist — which agents can spawn which sandbox types
AGENT_ALLOWLIST = {
    "coder": ["code-interpreter", "vscode", "aio"],
    "reviewer": ["code-interpreter"],
    "tester": ["code-interpreter", "aio"],
    "researcher": ["code-interpreter", "playwright"],
    "cosmo": list(SANDBOX_TYPES.keys()),
    "wanda": list(SANDBOX_TYPES.keys()),
}

# Default max TTL for child sandboxes (seconds)
DEFAULT_TTL = 600
MAX_TTL = 1800

# Track active sandboxes for TTL reaping: sandbox_id → (Sandbox, expiry_timestamp)
_active_sandboxes: dict[str, tuple] = {}
_reaper_started = False


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
            expired = [sid for sid, (_, exp) in _active_sandboxes.items() if now >= exp]
            for sid in expired:
                sandbox, _ = _active_sandboxes.pop(sid, (None, None))
                if sandbox:
                    try:
                        asyncio.run(sandbox.stop())
                    except Exception:
                        pass

    t = threading.Thread(target=reaper, daemon=True)
    t.start()


def spawn_sandbox(type: str, timeout: int | None = None) -> dict:
    """Create a child sandbox of the given type via ROCK SDK."""
    try:
        from rock.sdk.sandbox.client import Sandbox
        from rock.sdk.sandbox.config import SandboxConfig
    except ImportError:
        return {"error": "rl-rock not installed — run: pip install rl-rock"}

    if type not in SANDBOX_TYPES:
        return {"error": f"Unknown sandbox type: {type}. Available: {list(SANDBOX_TYPES.keys())}"}

    allowed = AGENT_ALLOWLIST.get(AGENT_NAME, [])
    if AGENT_NAME != "unknown" and type not in allowed:
        return {"error": f"Agent '{AGENT_NAME}' not allowed to spawn '{type}'. Allowed: {allowed}"}

    spec = SANDBOX_TYPES[type]
    ttl = min(timeout or DEFAULT_TTL, MAX_TTL)

    async def _create():
        cfg = SandboxConfig(image=spec["image"]) if spec.get("image") else SandboxConfig()
        sandbox = Sandbox(cfg)
        await sandbox.start()
        await sandbox.remote_user.create_remote_user("rock")
        return sandbox

    try:
        sandbox = asyncio.run(_create())
    except Exception as e:
        return {"error": f"Failed to create ROCK sandbox: {e}"}

    sandbox_id = str(id(sandbox))
    _active_sandboxes[sandbox_id] = (sandbox, time.time() + ttl)
    _start_reaper()

    return {
        "sandbox_id": sandbox_id,
        "type": type,
        "image": spec.get("image", "default"),
        "ttl": ttl,
    }


def exec_in_sandbox(sandbox_id: str, command: str) -> dict:
    """Run a command inside a ROCK sandbox."""
    try:
        from rock.sdk.sandbox.client import RunMode
        from rock.actions.sandbox.request import CreateBashSessionRequest
    except ImportError:
        return {"error": "rl-rock not installed — run: pip install rl-rock"}

    entry = _active_sandboxes.get(sandbox_id)
    if not entry:
        return {"error": f"Unknown sandbox: {sandbox_id}"}

    sandbox, _ = entry
    OUTPUT_CAP = 131072

    async def _exec():
        await sandbox.create_session(
            CreateBashSessionRequest(remote_user="rock", session="exec")
        )
        resp = await sandbox.arun(
            cmd=command,
            mode=RunMode.NOHUP,
            session="exec",
            wait_timeout=300,
            response_limited_bytes_in_nohup=OUTPUT_CAP,
        )
        output = getattr(resp, "output", "") or ""
        exit_code = getattr(resp, "exit_code", 0)

        # Fetch remainder if output was capped
        output_file = getattr(resp, "output_file", None)
        if output_file and len(output) >= OUTPUT_CAP:
            try:
                remainder = await sandbox.read_file_by_line_range(
                    output_file,
                    start_line=output.count("\n") + 1,
                    lines_per_request=5000,
                )
                output += "\n[...truncated...]\n" + getattr(remainder, "content", "")
            except Exception:
                output += "\n[output truncated at 128 KB]"

        return {"output": output, "exit_code": exit_code}

    try:
        return asyncio.run(_exec())
    except Exception as e:
        return {"error": f"exec failed: {e}"}


def read_sandbox_file(sandbox_id: str, path: str) -> dict:
    """Read a file from sandbox filesystem via ROCK file_system API."""
    entry = _active_sandboxes.get(sandbox_id)
    if not entry:
        return {"error": f"Unknown sandbox: {sandbox_id}"}

    sandbox, _ = entry

    async def _read():
        result = await sandbox.file_system.read_file_by_line_range(
            path,
            start_line=1,
            lines_per_request=5000,
        )
        return {"path": path, "content": getattr(result, "content", "")}

    try:
        return asyncio.run(_read())
    except Exception as e:
        return {"error": f"read failed: {e}"}


def write_sandbox_file(sandbox_id: str, path: str, content: str) -> dict:
    """Write a file into sandbox via ROCK file_system.upload_dir."""
    entry = _active_sandboxes.get(sandbox_id)
    if not entry:
        return {"error": f"Unknown sandbox: {sandbox_id}"}

    sandbox, _ = entry

    async def _write():
        import tempfile, os as _os
        with tempfile.TemporaryDirectory() as tmp:
            # Write content to a temp file matching the target basename
            basename = _os.path.basename(path)
            local_path = _os.path.join(tmp, basename)
            with open(local_path, "w") as f:
                f.write(content)
            target_dir = _os.path.dirname(path) or "/"
            upload = await sandbox.file_system.upload_dir(
                source_dir=tmp,
                target_dir=target_dir,
                extract_timeout=30,
            )
            if upload.exit_code != 0:
                return {"error": f"upload failed: {upload.failure_reason}"}
        return {"path": path, "status": "written"}

    try:
        return asyncio.run(_write())
    except Exception as e:
        return {"error": f"write failed: {e}"}


def get_sandbox_endpoints(sandbox_id: str) -> dict:
    """Get exposed ports and connection info for a sandbox."""
    entry = _active_sandboxes.get(sandbox_id)
    if not entry:
        return {"error": f"Unknown sandbox: {sandbox_id}"}

    sandbox, expiry = entry
    ports = getattr(sandbox, "exposed_ports", []) or []
    return {
        "sandbox_id": sandbox_id,
        "status": "running",
        "expires_in": max(0, int(expiry - time.time())),
        "ports": ports,
    }


def kill_sandbox(sandbox_id: str) -> dict:
    """Terminate and cleanup a sandbox."""
    entry = _active_sandboxes.pop(sandbox_id, None)
    if not entry:
        return {"error": f"Unknown sandbox: {sandbox_id}"}

    sandbox, _ = entry
    try:
        asyncio.run(sandbox.stop())
    except Exception as e:
        return {"error": f"stop failed: {e}"}

    return {"sandbox_id": sandbox_id, "status": "terminated"}


# MCP tool definitions
TOOLS = [
    {
        "name": "spawn_sandbox",
        "description": "Create a child sandbox (code-interpreter, playwright, node, vscode, aio)",
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
        "description": "Get exposed ports and connection info for a sandbox",
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
                "serverInfo": {"name": "sandbox", "version": "0.2.0"},
            },
        }
    elif method == "tools/list":
        return {"jsonrpc": "2.0", "id": req_id, "result": {"tools": TOOLS}}
    elif method == "tools/call":
        tool_name = params.get("name", "")
        args = params.get("arguments", {})

        dispatch = {
            "spawn_sandbox": spawn_sandbox,
            "exec_in_sandbox": exec_in_sandbox,
            "read_sandbox_file": read_sandbox_file,
            "write_sandbox_file": write_sandbox_file,
            "get_sandbox_endpoints": get_sandbox_endpoints,
            "kill_sandbox": kill_sandbox,
        }

        if tool_name not in dispatch:
            return {
                "jsonrpc": "2.0",
                "id": req_id,
                "error": {"code": -32601, "message": f"Unknown tool: {tool_name}"},
            }

        result = dispatch[tool_name](**args)
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
