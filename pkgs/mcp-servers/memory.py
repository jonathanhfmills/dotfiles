#!/usr/bin/env python3
"""MCP Server: Agent Memory — persistent memory read/write for agents.

Exposes MCP tools over stdio (JSON-RPC 2.0):
  - read_memory(agent) → returns agent's MEMORY.md contents
  - write_memory(agent, content) → overwrites agent's MEMORY.md
  - append_memory(agent, section, entry) → appends to a section in MEMORY.md
  - read_identity(agent) → returns agent's identity files
"""
import json
import os
import re
import sys


AGENTS_DIR = os.environ.get("AGENTS_DIR", "/var/lib/orchestrator/agents")
WANDA_DIR = os.environ.get("WANDA_DIR", "/var/lib/orchestrator/wanda")


def _get_memory_path(agent: str) -> str:
    """Get the MEMORY.md path for an agent."""
    if agent == "wanda":
        return os.path.join(WANDA_DIR, "MEMORY.md")
    return os.path.join(AGENTS_DIR, agent, "MEMORY.md")


def read_memory(agent: str) -> dict:
    """Read an agent's MEMORY.md file."""
    path = _get_memory_path(agent)
    if not os.path.exists(path):
        return {"agent": agent, "content": "", "exists": False}
    with open(path) as f:
        return {"agent": agent, "content": f.read(), "exists": True}


def write_memory(agent: str, content: str) -> dict:
    """Overwrite an agent's MEMORY.md file."""
    path = _get_memory_path(agent)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(content)
    return {"agent": agent, "status": "written", "path": path}


def append_memory(agent: str, section: str, entry: str) -> dict:
    """Append an entry to a specific section in an agent's MEMORY.md.

    Finds the section header (## Section) and appends the entry after existing
    content in that section (before the next ## header or end of file).
    """
    path = _get_memory_path(agent)
    if not os.path.exists(path):
        # Create with section and entry
        content = f"# MEMORY.md — {agent}\n\n## {section}\n\n{entry}\n"
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            f.write(content)
        return {"agent": agent, "section": section, "status": "created"}

    with open(path) as f:
        content = f.read()

    # Find the section
    section_pattern = re.compile(rf"^## {re.escape(section)}\s*$", re.MULTILINE)
    match = section_pattern.search(content)

    if match:
        # Find the next ## header or end of file
        next_header = re.search(r"^## ", content[match.end():], re.MULTILINE)
        if next_header:
            insert_pos = match.end() + next_header.start()
        else:
            insert_pos = len(content)

        # Insert entry before next section (with newline padding)
        new_content = content[:insert_pos].rstrip() + f"\n- {entry}\n\n" + content[insert_pos:]
    else:
        # Section doesn't exist — append at end
        new_content = content.rstrip() + f"\n\n## {section}\n\n- {entry}\n"

    with open(path, "w") as f:
        f.write(new_content)

    return {"agent": agent, "section": section, "status": "appended"}


def read_identity(agent: str) -> dict:
    """Read an agent's identity files (IDENTITY.md, SOUL.md, USER.md)."""
    if agent == "wanda":
        base = WANDA_DIR
    else:
        base = os.path.join(AGENTS_DIR, agent)

    files = {}
    for name in ["IDENTITY.md", "SOUL.md", "USER.md"]:
        path = os.path.join(base, name)
        if os.path.exists(path):
            with open(path) as f:
                files[name] = f.read()

    return {"agent": agent, "identity_files": files}


# MCP tool definitions
TOOLS = [
    {
        "name": "read_memory",
        "description": "Read an agent's MEMORY.md persistent memory file",
        "inputSchema": {
            "type": "object",
            "properties": {
                "agent": {
                    "type": "string",
                    "description": "Agent ID (wanda, cosmo, coder, reviewer, deployer, writer, reader)",
                },
            },
            "required": ["agent"],
        },
    },
    {
        "name": "write_memory",
        "description": "Overwrite an agent's MEMORY.md file with new content",
        "inputSchema": {
            "type": "object",
            "properties": {
                "agent": {"type": "string", "description": "Agent ID"},
                "content": {"type": "string", "description": "Full MEMORY.md content"},
            },
            "required": ["agent", "content"],
        },
    },
    {
        "name": "append_memory",
        "description": "Append an entry to a specific section in an agent's MEMORY.md",
        "inputSchema": {
            "type": "object",
            "properties": {
                "agent": {"type": "string", "description": "Agent ID"},
                "section": {
                    "type": "string",
                    "description": "Section name (e.g., 'Patterns', 'Lessons', 'Preferences')",
                },
                "entry": {"type": "string", "description": "The entry text to append"},
            },
            "required": ["agent", "section", "entry"],
        },
    },
    {
        "name": "read_identity",
        "description": "Read an agent's identity files (IDENTITY.md, SOUL.md, USER.md)",
        "inputSchema": {
            "type": "object",
            "properties": {
                "agent": {"type": "string", "description": "Agent ID"},
            },
            "required": ["agent"],
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
                "serverInfo": {"name": "memory", "version": "0.1.0"},
            },
        }
    elif method == "tools/list":
        return {"jsonrpc": "2.0", "id": req_id, "result": {"tools": TOOLS}}
    elif method == "tools/call":
        tool_name = params.get("name", "")
        args = params.get("arguments", {})

        if tool_name == "read_memory":
            result = read_memory(**args)
        elif tool_name == "write_memory":
            result = write_memory(**args)
        elif tool_name == "append_memory":
            result = append_memory(**args)
        elif tool_name == "read_identity":
            result = read_identity(**args)
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
