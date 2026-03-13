#!/usr/bin/env python3
"""MCP Server: ClawHub — skill discovery and vetting pipeline.

Exposes MCP tools over stdio (JSON-RPC 2.0):
  - search_skills(query) → search ClawHub for matching skills
  - vet_skill(skill_id) → run skill in OpenSandbox for safety verification
  - list_verified() → return locally verified skills
  - load_skill(skill_id) → load a verified skill for NullClaw execution

Skills flow: ClawHub → OpenClaw (sandbox vetting) → verified/ → NullClaw
"""
import json
import os
import sys

import urllib.request


OPENSANDBOX_URL = os.environ.get("OPENSANDBOX_URL", "http://localhost:8080")
VERIFIED_DIR = os.environ.get("VERIFIED_DIR", "/var/lib/orchestrator/shared/skills/verified")


def search_skills(query: str, limit: int = 10) -> dict:
    """Search ClawHub for skills matching a query.

    NOTE: ClawHub API endpoint TBD — this is a placeholder.
    ClawHub had the ClawHavoc incident (341+ malicious skills).
    ALL results must go through vet_skill() before use.
    """
    # Placeholder — real implementation calls ClawHub API
    return {
        "query": query,
        "results": [],
        "warning": "ClawHub search not yet connected. Use list_verified() for local skills.",
    }


def vet_skill(skill_id: str, skill_source: str) -> dict:
    """Run a skill in OpenSandbox with Carapace permissions for safety verification.

    Tests the skill in an isolated container with:
    - Dropped capabilities (no NET_ADMIN, SYS_ADMIN, etc.)
    - Network egress deny-by-default
    - PID limit 512
    - 5 minute timeout

    If safe: writes to verified/ with scoped permissions.
    """
    try:
        # Create sandbox for skill vetting
        request_body = json.dumps({
            "image": {"uri": "ghcr.io/nullclaw/nullclaw:latest"},
            "timeout": 300,
            "resourceLimits": {"cpu": "500m", "memory": "512Mi"},
            "env": {"SKILL_SOURCE": skill_source},
            "networkPolicy": {
                "defaultAction": "deny",
                "egress": [],
            },
        }).encode()

        req = urllib.request.Request(
            f"{OPENSANDBOX_URL}/v1/sandboxes",
            data=request_body,
            headers={"Content-Type": "application/json"},
        )

        with urllib.request.urlopen(req, timeout=30) as resp:
            result = json.loads(resp.read())
            sandbox_id = result.get("id")

        if not sandbox_id:
            return {"skill_id": skill_id, "status": "error", "reason": "Failed to create sandbox"}

        # TODO: Monitor sandbox execution, check for malicious behavior
        # For now, return pending status
        return {
            "skill_id": skill_id,
            "sandbox_id": sandbox_id,
            "status": "vetting",
            "message": "Skill submitted for sandboxed verification",
        }
    except Exception as e:
        return {"skill_id": skill_id, "status": "error", "reason": str(e)}


def list_verified() -> dict:
    """List locally verified skills ready for NullClaw execution."""
    verified = []
    os.makedirs(VERIFIED_DIR, exist_ok=True)
    for fname in os.listdir(VERIFIED_DIR):
        if fname.endswith(".json"):
            path = os.path.join(VERIFIED_DIR, fname)
            with open(path) as f:
                skill = json.load(f)
                verified.append(skill)
    return {"verified_skills": verified, "count": len(verified)}


def load_skill(skill_id: str) -> dict:
    """Load a verified skill definition for NullClaw execution."""
    path = os.path.join(VERIFIED_DIR, f"{skill_id}.json")
    if not os.path.exists(path):
        return {"error": f"Skill {skill_id} not verified. Run vet_skill() first."}
    with open(path) as f:
        return json.load(f)


# MCP tool definitions
TOOLS = [
    {
        "name": "search_skills",
        "description": "Search ClawHub for skills (results must be vetted before use)",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "Search query"},
                "limit": {"type": "integer", "description": "Max results", "default": 10},
            },
            "required": ["query"],
        },
    },
    {
        "name": "vet_skill",
        "description": "Run a ClawHub skill in OpenSandbox for safety verification",
        "inputSchema": {
            "type": "object",
            "properties": {
                "skill_id": {"type": "string", "description": "Skill identifier"},
                "skill_source": {"type": "string", "description": "Skill source code or URL"},
            },
            "required": ["skill_id", "skill_source"],
        },
    },
    {
        "name": "list_verified",
        "description": "List locally verified skills ready for NullClaw execution",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "load_skill",
        "description": "Load a verified skill definition for NullClaw",
        "inputSchema": {
            "type": "object",
            "properties": {
                "skill_id": {"type": "string", "description": "Verified skill ID"},
            },
            "required": ["skill_id"],
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
                "serverInfo": {"name": "clawhub", "version": "0.1.0"},
            },
        }
    elif method == "tools/list":
        return {"jsonrpc": "2.0", "id": req_id, "result": {"tools": TOOLS}}
    elif method == "tools/call":
        tool_name = params.get("name", "")
        args = params.get("arguments", {})

        handlers = {
            "search_skills": search_skills,
            "vet_skill": vet_skill,
            "list_verified": list_verified,
            "load_skill": load_skill,
        }
        handler = handlers.get(tool_name)
        if not handler:
            return {
                "jsonrpc": "2.0",
                "id": req_id,
                "error": {"code": -32601, "message": f"Unknown tool: {tool_name}"},
            }

        result = handler(**args)
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
