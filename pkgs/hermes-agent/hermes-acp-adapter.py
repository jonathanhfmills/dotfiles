#!/usr/bin/env python3
"""Hermes ACP Adapter — wraps Hermes AIAgent for Agent Client Protocol.

Translates ACP protocol (JSON-RPC 2.0 over NDJSON stdio) to Hermes Agent's
AIAgent.run_conversation() method. Hermes handles all routing, delegation,
and tool calling internally.

This adapter is a stopgap until the upstream acp_adapter/ (commit cc61f54)
lands on main. Once it does, replace this with `hermes-acp` entry point.

Environment variables:
  OPENAI_BASE_URL  — SGLang endpoint (default: http://localhost:11434/v1)
  OPENAI_API_KEY   — API key (default: ollama)
  LLM_MODEL        — model identifier (default: openai/Qwen/Qwen3.5-9B)
  HERMES_CONFIG    — path to config.yaml
  TASK_FILE        — path to task.json with prompt
"""
import json
import os
import sys
import uuid


def send_jsonrpc(obj: dict):
    """Write a JSON-RPC message to stdout."""
    sys.stdout.write(json.dumps(obj) + "\n")
    sys.stdout.flush()


def send_notification(session_id: str, update_type: str, content: str):
    """Send an ACP session update notification."""
    send_jsonrpc({
        "jsonrpc": "2.0",
        "method": "notifications/session/update",
        "params": {
            "sessionId": session_id,
            "update": {
                "sessionUpdate": update_type,
                "content": content,
            },
        },
    })


def run_hermes(prompt: str, session_id: str) -> str:
    """Run Hermes AIAgent with the given prompt.

    Hermes handles routing, delegation, and tool calling internally.
    The MoE evaluator, MCP tools, and delegate_task are all available
    through Hermes's native tool system.
    """
    try:
        from run_agent import AIAgent
    except ImportError:
        # Try alternate import path
        try:
            from hermes_agent.run_agent import AIAgent
        except ImportError:
            return "Error: hermes-agent not installed. Run hermes-bootstrap first."

    model = os.environ.get("LLM_MODEL", "openai/Qwen/Qwen3.5-9B")
    base_url = os.environ.get("OPENAI_BASE_URL", "http://localhost:11434/v1")
    api_key = os.environ.get("OPENAI_API_KEY", "ollama")

    def on_thinking(text):
        send_notification(session_id, "agent_thought_chunk", text[:300])

    def on_step(step_info):
        if isinstance(step_info, dict):
            tool_name = step_info.get("tool", "")
            if tool_name:
                send_notification(session_id, "tool_use", f"Using: {tool_name}")

    try:
        agent = AIAgent(
            model=model,
            base_url=base_url,
            api_key=api_key,
            max_iterations=50,
            quiet_mode=True,
            save_trajectories=True,
            thinking_callback=on_thinking,
            step_callback=on_step,
        )

        send_notification(session_id, "agent_thought_chunk", f"Hermes Brain using {model}")
        result = agent.chat(prompt)
        return result if result else "No output from Hermes"

    except Exception as e:
        return f"Hermes error: {str(e)}"


def handle_request(request: dict) -> dict | None:
    """Handle an ACP JSON-RPC request."""
    method = request.get("method", "")
    req_id = request.get("id")
    params = request.get("params", {})

    if method == "initialize":
        return {
            "jsonrpc": "2.0",
            "id": req_id,
            "result": {
                "protocolVersion": "2024-11-05",
                "capabilities": {
                    "session": {"create": True, "prompt": True},
                },
                "serverInfo": {
                    "name": "hermes-brain",
                    "version": "0.1.0",
                },
            },
        }
    elif method == "session/new":
        session_id = str(uuid.uuid4())
        return {
            "jsonrpc": "2.0",
            "id": req_id,
            "result": {"sessionId": session_id},
        }
    elif method == "session/prompt":
        session_id = params.get("sessionId", "unknown")
        # Extract prompt from ACP ContentBlock format
        prompt_blocks = params.get("prompt", [])
        if isinstance(prompt_blocks, list):
            prompt = "\n".join(
                block.get("text", "") for block in prompt_blocks if block.get("type") == "text"
            )
        elif isinstance(prompt_blocks, str):
            prompt = prompt_blocks
        else:
            prompt = str(prompt_blocks)

        if not prompt:
            # Try reading from TASK_FILE
            task_file = os.environ.get("TASK_FILE", "")
            if task_file and os.path.exists(task_file):
                with open(task_file) as f:
                    task = json.load(f)
                    prompt = task.get("prompt", "")

        if not prompt:
            return {
                "jsonrpc": "2.0",
                "id": req_id,
                "error": {"code": -32602, "message": "No prompt provided"},
            }

        send_notification(session_id, "agent_thought_chunk", "Starting Hermes Brain...")
        result = run_hermes(prompt, session_id)

        return {
            "jsonrpc": "2.0",
            "id": req_id,
            "result": {
                "content": [{"type": "text", "text": result}],
            },
        }
    elif method.startswith("notifications/"):
        return None
    else:
        return {
            "jsonrpc": "2.0",
            "id": req_id,
            "error": {"code": -32601, "message": f"Unknown method: {method}"},
        }


def main():
    """ACP adapter main loop — reads JSON-RPC from stdin, writes to stdout."""
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            request = json.loads(line)
            response = handle_request(request)
            if response is not None:
                send_jsonrpc(response)
        except json.JSONDecodeError:
            send_jsonrpc({
                "jsonrpc": "2.0",
                "id": None,
                "error": {"code": -32700, "message": "Parse error"},
            })
        except Exception as e:
            send_jsonrpc({
                "jsonrpc": "2.0",
                "id": None,
                "error": {"code": -32603, "message": f"Internal error: {str(e)}"},
            })


if __name__ == "__main__":
    main()
