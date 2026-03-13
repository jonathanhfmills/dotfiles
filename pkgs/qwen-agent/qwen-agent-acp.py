#!/usr/bin/env python3
"""Qwen-Agent ACP Adapter — speaks Agent Client Protocol over stdio.

Translates ACP protocol (JSON-RPC 2.0 over NDJSON) to Qwen-Agent's Assistant
with native ATIC tool calling. Uses agent-sandbox SDK for AIO Sandbox tools.

ACP flow: initialize → session/new → session/prompt → (notifications) → result

Environment variables:
  SGLANG_MODEL     — model name (default: Qwen/Qwen3.5-9B)
  OPENAI_BASE_URL  — SGLang endpoint (default: http://172.17.0.1:11434/v1)
  OPENAI_API_KEY   — API key (default: ollama)
  SANDBOX_API_URL  — OpenSandbox API for AIO Sandbox lifecycle
  TASK_FILE        — path to task.json with prompt
"""
import json
import os
import sys
import time
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


def run_agent(prompt: str, session_id: str) -> str:
    """Run Qwen-Agent Assistant with the given prompt.

    Uses agent-sandbox SDK for AIO Sandbox tool access if available.
    Falls back to pure LLM completion if sandbox is unavailable.
    """
    # Lazy imports — installed via pip bootstrap
    from qwen_agent.agents import Assistant

    model = os.environ.get("SGLANG_MODEL", "Qwen/Qwen3.5-9B")
    base_url = os.environ.get("OPENAI_BASE_URL", "http://172.17.0.1:11434/v1")
    api_key = os.environ.get("OPENAI_API_KEY", "ollama")

    llm_cfg = {
        "model": model,
        "model_type": "qwenvl_oai",
        "model_server": base_url,
        "api_key": api_key,
        "generate_cfg": {
            "use_raw_api": True,
            "extra_body": {"chat_template_kwargs": {"enable_thinking": True}},
        },
    }

    # Build tool list — try AIO Sandbox SDK, fall back to empty
    tools = []
    sandbox_client = None

    sandbox_api = os.environ.get("SANDBOX_API_URL", "")
    if sandbox_api:
        try:
            from agent_sandbox import AioSandboxClient
            sandbox_client = AioSandboxClient(api_url=sandbox_api)
            send_notification(session_id, "agent_thought_chunk", "Connected to AIO Sandbox")
        except Exception as e:
            send_notification(session_id, "agent_thought_chunk", f"AIO Sandbox unavailable: {e}")

    # Add MCP servers if configured
    mcp_config = {}
    mcp_servers_dir = os.environ.get("MCP_SERVERS_DIR", "")
    if mcp_servers_dir:
        for server_name in ["dispatch", "escalation", "memory"]:
            server_path = os.path.join(mcp_servers_dir, f"{server_name}.py")
            if os.path.exists(server_path):
                mcp_config[server_name] = {
                    "command": "python",
                    "args": [server_path],
                }

    function_list = []
    if mcp_config:
        function_list.append({"mcpServers": mcp_config})

    # Create assistant
    agent = Assistant(
        llm=llm_cfg,
        name="qwen-agent-engineer",
        description="Qwen-Agent Engineer — native ATIC tool calling with MCP tools",
        function_list=function_list if function_list else None,
    )

    send_notification(session_id, "agent_thought_chunk", f"Using model: {model}")

    # Run the agent
    messages = [{"role": "user", "content": prompt}]
    result_parts = []

    try:
        for responses in agent.run(messages=messages):
            for response in responses:
                if response.get("role") == "assistant":
                    content = response.get("content", "")
                    if content:
                        result_parts.append(content)
                        send_notification(session_id, "agent_thought_chunk", content[:200])
    except Exception as e:
        return f"Agent error: {str(e)}"
    finally:
        if sandbox_client:
            try:
                sandbox_client.close()
            except Exception:
                pass

    return "\n".join(result_parts) if result_parts else "No output from agent"


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
                    "name": "qwen-agent-engineer",
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

        send_notification(session_id, "agent_thought_chunk", "Starting Qwen-Agent Engineer...")
        result = run_agent(prompt, session_id)

        return {
            "jsonrpc": "2.0",
            "id": req_id,
            "result": {
                "content": [{"type": "text", "text": result}],
            },
        }
    elif method.startswith("notifications/"):
        return None  # No response for notifications
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
                "id": request.get("id") if "request" in dir() else None,
                "error": {"code": -32603, "message": f"Internal error: {str(e)}"},
            })


if __name__ == "__main__":
    main()
