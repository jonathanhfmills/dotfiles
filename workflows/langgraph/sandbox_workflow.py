"""LangGraph universal execution engine — sandbox workflow.

Replaces per-backend execution with a StateGraph that dynamically selects
models per-node based on confidence, cost, and task type.

Execution modes:
  auto (default): Local chain 0.8B → 4B → 9B, no API costs.
  claude-code:    Claude CLI end-to-end in sandbox (future).
  gemini:         Gemini CLI end-to-end in sandbox (future).
  mixed:          Qwen cheap nodes + frontier quality nodes (future).

Dynamic expert agents: When task.agent matches an agents/*/SOUL.md, the run
node spawns an ADK Agent with that identity and the selected model tier.
The fleet's 41 experts are available on demand — no pre-provisioning needed.

Every escalation generates CSPO training data for the RL loop.
"""

import asyncio
import glob as glob_mod
import json
import os
import time
from typing import Annotated, Any, Literal

from langchain_openai import ChatOpenAI
from langgraph.checkpoint.memory import MemorySaver
from langgraph.graph import END, StateGraph
from typing_extensions import TypedDict

# ---------------------------------------------------------------------------
# Model router — local-first, no API costs in auto mode
# ---------------------------------------------------------------------------

MODELS = {
    "qwen-08b": lambda: ChatOpenAI(
        model="Qwen/Qwen3.5-0.8B",
        openai_api_base="http://172.17.0.1:11436/v1",
        openai_api_key="ollama",
    ),
    "qwen-4b": lambda: ChatOpenAI(
        model="Qwen/Qwen3.5-4B",
        openai_api_base="http://172.17.0.1:11434/v1",
        openai_api_key="ollama",
    ),
    "qwen-9b": lambda: ChatOpenAI(
        model="Qwen/Qwen3.5-9B",
        openai_api_base="http://172.17.0.1:11435/v1",
        openai_api_key="ollama",
    ),
    # Future: frontier models (plumbed but not active)
    "claude-code": lambda: None,  # Runs `claude` CLI in sandbox
    "gemini-cli": lambda: None,   # Runs `gemini` CLI in sandbox
}

# Optionally add claude-api if langchain-anthropic is available
try:
    from langchain_anthropic import ChatAnthropic
    MODELS["claude-api"] = lambda: ChatAnthropic(
        model=os.getenv("ANTHROPIC_MODEL", "claude-sonnet-4-20250514"),
    )
except ImportError:
    pass

# Local escalation chain: 0.8B (grunt) → 4B (expert) → 9B (brain)
LOCAL_CHAIN = ["qwen-08b", "qwen-4b", "qwen-9b"]


def get_model_for_node(node_name: str, mode: str, state: dict) -> str:
    """Select model based on execution mode and escalation state."""
    if mode == "claude-code":
        return "claude-code"
    if mode == "gemini":
        return "gemini-cli"
    # Auto mode: walk the local chain based on escalation index
    escalation_index = state.get("escalation_index", 0)
    return LOCAL_CHAIN[min(escalation_index, len(LOCAL_CHAIN) - 1)]


# ---------------------------------------------------------------------------
# Frontier CLI runners (plumbed now, activated when budget allows)
# ---------------------------------------------------------------------------

async def run_with_claude_code(sandbox_exec, command: str) -> str:
    """Run command via Claude CLI inside sandbox."""
    await sandbox_exec("npm i -g @anthropic-ai/claude-code@latest")
    result = await sandbox_exec(f'claude "{command}"')
    return result


async def run_with_gemini_cli(sandbox_exec, command: str) -> str:
    """Run command via Gemini CLI inside sandbox."""
    await sandbox_exec("npm i -g @google/gemini-cli@latest")
    result = await sandbox_exec(f'gemini "{command}"')
    return result


# ---------------------------------------------------------------------------
# Dynamic expert agents via google-adk
# ---------------------------------------------------------------------------

# Agent SOUL.md directory (mounted into container via workspace volume)
AGENTS_DIR = os.environ.get("AGENTS_DIR", "/workspace/agent/agents")

# LiteLLM model names for ADK (maps to vLLM/SGLang endpoints)
ADK_MODELS = {
    "qwen-08b": "openai/Qwen/Qwen3.5-0.8B",
    "qwen-4b": "openai/Qwen/Qwen3.5-4B",
    "qwen-9b": "openai/Qwen/Qwen3.5-9B",
}


def _find_soul_md(agent_name: str) -> str | None:
    """Find SOUL.md for an agent by name."""
    soul_path = os.path.join(AGENTS_DIR, agent_name, "SOUL.md")
    if os.path.exists(soul_path):
        with open(soul_path) as f:
            return f.read()
    return None


def _list_available_experts() -> list[str]:
    """List all available expert agents (those with SOUL.md)."""
    experts = []
    if not os.path.isdir(AGENTS_DIR):
        return experts
    for entry in os.listdir(AGENTS_DIR):
        if os.path.exists(os.path.join(AGENTS_DIR, entry, "SOUL.md")):
            experts.append(entry)
    return sorted(experts)


async def run_adk_expert(agent_name: str, model_key: str, prompt: str) -> str:
    """Spawn an ADK Agent with the given SOUL.md identity and run a task.

    Uses google.adk to create an agent on the fly, seeded with the expert's
    SOUL.md as its instruction. The model is selected from the local chain
    based on the current escalation tier.
    """
    soul_md = _find_soul_md(agent_name)
    if not soul_md:
        return f"[adk] No SOUL.md found for agent '{agent_name}' in {AGENTS_DIR}"

    adk_model_name = ADK_MODELS.get(model_key)
    if not adk_model_name:
        return f"[adk] No ADK model mapping for '{model_key}'"

    try:
        from google.adk.agents import Agent
        from google.adk.models.lite_llm import LiteLlm
        from google.adk.runners import InMemoryRunner
        from google.genai import types

        model = LiteLlm(model=adk_model_name)
        agent = Agent(
            name=agent_name,
            model=model,
            description=f"Expert: {agent_name}",
            instruction=soul_md,
        )

        runner = InMemoryRunner(agent=agent, app_name=f"expert_{agent_name}")
        session = await runner.session_service.create_session(
            app_name=f"expert_{agent_name}",
            user_id="langgraph",
        )

        content = types.Content(
            role="user",
            parts=[types.Part.from_text(text=prompt)],
        )

        result = ""
        async for event in runner.run_async(
            user_id="langgraph",
            session_id=session.id,
            new_message=content,
        ):
            if event.is_final_response() and event.content:
                for part in event.content.parts:
                    if part.text:
                        result += part.text

        return result or "[adk] Expert returned empty response"

    except ImportError:
        return "[adk] google-adk not installed — run adk-bootstrap first"
    except Exception as e:
        return f"[adk] Expert '{agent_name}' failed: {e}"


# ---------------------------------------------------------------------------
# UncertaintyManager — scores output confidence for routing decisions
# ---------------------------------------------------------------------------

class UncertaintyManager:
    """Scores run output confidence. Rule-based initially, learns from CSPO."""

    def __init__(self, policy_path: str | None = None):
        self.policy = None
        if policy_path and os.path.exists(policy_path):
            try:
                from stable_baselines3 import DQN
                self.policy = DQN.load(policy_path)
            except (ImportError, Exception):
                pass

    async def score(self, run_output: str, task: dict, state: dict) -> float:
        """Score output confidence 0.0-1.0."""
        if self.policy is not None:
            features = self._extract_features(state)
            action, _ = self.policy.predict(features)
            # Map DQN action to confidence: 0=high, 1=medium, 2=low
            return [0.95, 0.60, 0.30][int(action)]

        # Rule-based fallback
        if not run_output or not run_output.strip():
            return 0.0

        score = 0.5
        output_len = len(run_output.strip())

        # Non-trivial output is a positive signal
        if output_len > 10:
            score += 0.2
        if output_len > 100:
            score += 0.1

        # Error patterns reduce confidence
        error_patterns = ["error", "traceback", "exception", "failed", "segfault"]
        output_lower = run_output.lower()
        for pattern in error_patterns:
            if pattern in output_lower:
                score -= 0.2
                break

        # Partial completion patterns
        if "timeout" in output_lower or "killed" in output_lower:
            score -= 0.3

        return max(0.0, min(1.0, score))

    def _extract_features(self, state: dict):
        """Extract observation features for DQN policy."""
        import numpy as np
        return np.array([
            len(state.get("task", {}).get("category", "")),
            state.get("escalation_index", 0),
            state.get("attempt", 0),
            len(state.get("run_output", "")),
        ], dtype="float32")


# ---------------------------------------------------------------------------
# Graph state
# ---------------------------------------------------------------------------

class SandboxState(TypedDict):
    # Task input
    task: dict
    execution_mode: str

    # Sandbox lifecycle
    sandbox_id: str
    sandbox_domain: str

    # Execution state
    current_model: str
    escalation_index: int
    attempt: int
    max_attempts: int

    # Run results
    run_output: str
    last_error: str
    success: bool

    # CSPO tracking
    trajectory: list[dict]
    models_used: list[str]


# ---------------------------------------------------------------------------
# Graph nodes
# ---------------------------------------------------------------------------

uncertainty_manager = UncertaintyManager(
    policy_path=os.environ.get("UM_POLICY_CHECKPOINT"),
)


async def create_sandbox(state: SandboxState) -> dict:
    """Initialize workspace (we already run inside a sandbox)."""
    t0 = time.monotonic()
    os.makedirs("/workspace", exist_ok=True)
    duration_ms = int((time.monotonic() - t0) * 1000)

    return {
        "sandbox_id": "local",
        "trajectory": state.get("trajectory", []) + [{
            "node": "create", "model": "none", "duration_ms": duration_ms,
        }],
    }


async def prepare_sandbox(state: SandboxState) -> dict:
    """Write task files into the workspace."""
    t0 = time.monotonic()
    task = state["task"]

    for file_spec in task.get("files", []):
        path = file_spec["path"]
        content = file_spec["content"]
        try:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w") as f:
                f.write(content)
        except Exception as e:
            print(f"[prepare] Warning: failed to write {path}: {e}")

    duration_ms = int((time.monotonic() - t0) * 1000)
    return {
        "trajectory": state.get("trajectory", []) + [{
            "node": "prepare", "model": "none", "duration_ms": duration_ms,
        }],
    }


async def run_command(state: SandboxState) -> dict:
    """Execute the task — via ADK expert agent or shell command.

    If task.agent is set and matches an agents/*/SOUL.md, spawns an ADK
    expert with that identity and the current model tier. Otherwise falls
    back to shell execution. This lets the graph dynamically create
    specialized agents on demand from the fleet's 41 experts.
    """
    t0 = time.monotonic()
    task = state["task"]
    mode = state.get("execution_mode", "auto")

    model_key = get_model_for_node("run", mode, state)
    command = task.get("command", "echo 'no command'")
    agent_name = task.get("agent")
    prompt = task.get("prompt", command)

    # Use fallback command on retry
    if state.get("attempt", 0) > 0 and task.get("fallback_command"):
        command = task["fallback_command"]

    run_output = ""
    last_error = ""

    # Path 1: ADK expert agent — spawn from SOUL.md
    if agent_name and _find_soul_md(agent_name):
        print(f"[run] Spawning ADK expert '{agent_name}' with model {model_key}")
        try:
            run_output = await asyncio.wait_for(
                run_adk_expert(agent_name, model_key, prompt),
                timeout=300,
            )
            if run_output.startswith("[adk]") and "failed" in run_output:
                last_error = run_output
        except asyncio.TimeoutError:
            last_error = f"ADK expert '{agent_name}' timed out after 300s"
        except Exception as e:
            last_error = f"ADK expert '{agent_name}' error: {e}"

    # Path 2: Frontier CLI (future)
    elif model_key == "claude-code":
        command = f'npm i -g @anthropic-ai/claude-code@latest && claude "{command}"'
        run_output, last_error = await _shell_exec(command)
    elif model_key == "gemini-cli":
        command = f'npm i -g @google/gemini-cli@latest && gemini "{command}"'
        run_output, last_error = await _shell_exec(command)

    # Path 2.5: ROCK sandbox — isolated container with non-root remote_user
    # Creates a fresh python:3.11 container via ROCK Admin, installs rocklet via
    # pip inside it, creates an unprivileged 'rock' user, uploads the workspace,
    # and runs the command. Provides stronger isolation than bare subprocess.
    elif task.get("backend") == "rock":
        run_output, last_error = await _run_in_rock_sandbox(command, state, task=task)

    # Path 3: iFlow CLI — Qwen3.5's native agent interface (in-distribution)
    # Spawns a child code-interpreter sandbox via OpenSandbox SDK, exactly as
    # Alibaba's reference implementation. The model knows this interface from training.
    elif task.get("backend") == "iflow":  # noqa: E501
        from opensandbox import Sandbox
        from opensandbox.config import ConnectionConfig
        from datetime import timedelta
        sandbox_domain = os.environ.get("SANDBOX_DOMAIN", "172.17.0.1:8080")
        cfg = ConnectionConfig(domain=sandbox_domain, request_timeout=timedelta(seconds=300))
        iflow_sb = await Sandbox.create(
            "opensandbox/code-interpreter:v1.0.2",
            connection_config=cfg,
            env={
                "IFLOW_apiKey":    os.environ.get("IFLOW_apiKey", "ollama"),
                "IFLOW_baseUrl":   os.environ.get("IFLOW_baseUrl", "http://172.17.0.1:11434/v1"),
                "IFLOW_modelName": os.environ.get("IFLOW_modelName", "Qwen/Qwen3.5-9B"),
            },
        )
        async with iflow_sb:
            await iflow_sb.commands.run("npm install -g @iflow-ai/iflow-cli@latest")
            iflow_prompt = task.get("prompt", command)
            exec_result = await iflow_sb.commands.run(f'iflow "{iflow_prompt}" --yolo')
            run_output = "\n".join(m.text for m in exec_result.logs.stdout)
            if exec_result.error:
                last_error = f"{exec_result.error.name}: {exec_result.error.value}"
            elif exec_result.logs.stderr:
                run_output += "\n" + "\n".join(m.text for m in exec_result.logs.stderr)
            await iflow_sb.kill()

    # Path 4: Direct shell execution
    else:
        run_output, last_error = await _shell_exec(command)

    duration_ms = int((time.monotonic() - t0) * 1000)
    models_used = state.get("models_used", [])
    if model_key not in models_used:
        models_used = models_used + [model_key]

    return {
        "run_output": run_output,
        "last_error": last_error,
        "current_model": model_key,
        "models_used": models_used,
        "trajectory": state.get("trajectory", []) + [{
            "node": "run", "model": model_key, "duration_ms": duration_ms,
            "agent": agent_name,
            "error": last_error or None,
        }],
    }


async def _shell_exec(command: str, timeout: int = 300) -> tuple[str, str]:
    """Run a shell command and return (output, error)."""
    try:
        proc = await asyncio.create_subprocess_shell(
            command,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=timeout)
        output = (stdout or b"").decode() + (stderr or b"").decode()
        error = ""
        if proc.returncode != 0:
            error = f"exit code {proc.returncode}: {(stderr or b'').decode()}"
        return output, error
    except asyncio.TimeoutError:
        return "", f"command timed out after {timeout}s"
    except Exception as e:
        return "", str(e)


def parse_swebench_result(output: str) -> bool:
    """Parse SWE-Bench test output — returns True if the task resolved (PASSED)."""
    import re
    match = re.search(
        r"SWEBench results starts here\s*(.*?)\s*SWEBench results ends here",
        output,
        re.DOTALL,
    )
    if not match:
        return False
    return match.group(1).strip() == "PASSED"


async def _run_in_rock_sandbox(command: str, state: dict, task: dict | None = None, timeout: int = 600) -> tuple[str, str]:
    """Execute a command in an isolated ROCK sandbox.

    Two execution paths depending on task fields:

    Agent path (task.agent_config set):
      Uses sandbox.agent.install(config) + sandbox.agent.run(instruction) —
      the official ROCK Agent API. Suitable for iFlow, NullClaw, or any agent
      YAML config. The agent handles its own session and runtime setup.

    Command path (default):
      1. Create sandbox (task.image or python:3.11 default)
      2. Create unprivileged 'rock' remote user
      3. Upload /workspace into sandbox, chown to 'rock'
      4. Provision RuntimeEnv (python/node/shell) with optional pip packages
      5. Open bash session as 'rock', run via arun(RunMode.NOHUP, wait_timeout)
      6. Fetch remainder via read_file_by_line_range if output > 128 KB

    Task fields:
      agent_config: str — path to agent YAML config (triggers agent path)
      image: str — Docker image URI (default: python:3.11)
      runtime: "python" (default) | "node" | "shell"
      pip: list[str] — packages to pre-install into the Python RuntimeEnv
      runtime_version: "3.11"|"3.12"|"default" (python) / "22.18.0"|"default" (node)

    ROCK_ENVHUB_BASE_URL must point to the ROCK Admin server (default localhost:8081).
    """
    try:
        from rock.sdk.sandbox.client import Sandbox, RunMode
        from rock.sdk.sandbox.config import SandboxConfig
        from rock.sdk.sandbox.runtime_env import RuntimeEnv, PythonRuntimeEnvConfig, NodeRuntimeEnvConfig
        from rock.actions.sandbox.request import (
            ChownRequest,
            CreateBashSessionRequest,
        )
    except ImportError:
        return "", "rl-rock not installed — run: pip install rl-rock"

    task = task or {}
    agent_config = task.get("agent_config")
    image = task.get("image")
    runtime = task.get("runtime", "python")
    pip_pkgs = task.get("pip") or []
    rt_version = task.get("runtime_version", "default")
    # nohup output cap: 128 KB inline; larger outputs read via read_file_by_line_range
    OUTPUT_CAP = 131072

    cfg = SandboxConfig(image=image) if image else SandboxConfig()
    sandbox = Sandbox(cfg)
    try:
        await sandbox.start()

        # --- Agent path: delegate entirely to sandbox.agent ---
        if agent_config:
            await sandbox.agent.install(config=agent_config)
            result = await sandbox.agent.run(command)
            output = getattr(result, "output", str(result)) or ""
            return output, ""

        # --- Command path ---

        # Create unprivileged execution user
        await sandbox.remote_user.create_remote_user("rock")

        # Upload task workspace into sandbox and transfer ownership
        workspace = "/workspace"
        if os.path.isdir(workspace):
            upload = await sandbox.file_system.upload_dir(
                source_dir=workspace,
                target_dir="/workspace",
                extract_timeout=60,
            )
            if upload.exit_code != 0:
                return "", f"upload_dir failed: {upload.failure_reason}"
            await sandbox.file_system.chown(
                ChownRequest(paths=["/workspace"], remote_user="rock", recursive=True)
            )

        # Provision RuntimeEnv — managed bin dir, optional pre-installed packages
        env = None
        if runtime == "node":
            env = await RuntimeEnv.create(sandbox, NodeRuntimeEnvConfig(version=rt_version))
        elif runtime == "python":
            env = await RuntimeEnv.create(sandbox, PythonRuntimeEnvConfig(
                version=rt_version,
                pip=pip_pkgs or None,
            ))
        # runtime == "shell": no RuntimeEnv, run command bare

        # Open bash session as non-root user
        await sandbox.create_session(
            CreateBashSessionRequest(remote_user="rock", session="main")
        )

        # Execute via arun — RunMode.NOHUP decouples execution from streaming;
        # wait_timeout replaces the outer asyncio.wait_for wrapper
        cmd = env.wrapped_cmd(command) if env else command
        resp = await sandbox.arun(
            cmd=cmd,
            mode=RunMode.NOHUP,
            session="main",
            wait_timeout=timeout,
            response_limited_bytes_in_nohup=OUTPUT_CAP,
        )

        output = getattr(resp, "output", "") or ""
        exit_code = getattr(resp, "exit_code", 0)

        # Fetch remainder from nohup output file if response was capped
        output_file = getattr(resp, "output_file", None)
        if output_file and len(output) >= OUTPUT_CAP:
            try:
                remainder = await sandbox.read_file_by_line_range(
                    output_file,
                    start_line=output.count("\n") + 1,
                    lines_per_request=5000,
                )
                output += "\n[...truncated, continuing from file...]\n"
                output += getattr(remainder, "content", "")
            except Exception:
                output += "\n[output truncated at 128 KB]"

        error = f"exit code {exit_code}: {output}" if exit_code != 0 else ""
        return output, error

    except Exception as e:
        return "", f"ROCK sandbox error: {e}"
    finally:
        try:
            await sandbox.stop()
        except Exception:
            pass


async def decide_next(state: SandboxState) -> Literal["inspect", "retry", "escalate"]:
    """Route based on execution result + UncertaintyManager confidence."""
    max_attempts = state.get("max_attempts", 2)
    attempt = state.get("attempt", 0)

    if state.get("last_error"):
        if attempt < max_attempts:
            return "retry"
        return "escalate"

    # No error — but is the output correct?
    um_score = await uncertainty_manager.score(
        state.get("run_output", ""), state.get("task", {}), state,
    )

    if um_score >= 0.85:
        return "inspect"
    # Frontier model: accept moderate confidence
    if um_score >= 0.50 and state.get("current_model") not in LOCAL_CHAIN:
        return "inspect"
    # Already at top of local chain — accept what we have
    if state.get("escalation_index", 0) >= len(LOCAL_CHAIN) - 1:
        return "inspect"
    return "escalate"


async def retry_node(state: SandboxState) -> dict:
    """Increment attempt counter for retry."""
    return {"attempt": state.get("attempt", 0) + 1, "last_error": ""}


async def escalate_node(state: SandboxState) -> dict:
    """Escalate to next model in chain."""
    return {
        "escalation_index": state.get("escalation_index", 0) + 1,
        "attempt": 0,
        "last_error": "",
    }


async def inspect_results(state: SandboxState) -> dict:
    """Read output, write CSPO entry."""
    task = state.get("task", {})
    was_escalated = state.get("escalation_index", 0) > 0

    cspo_entry = {
        "problem": {
            "description": task.get("command", ""),
            "decomposition": [f.get("path", "") for f in task.get("files", [])],
        },
        "solution": {
            "command": task.get("command", ""),
            "attempts": state.get("attempt", 0) + 1,
            "models_used": state.get("models_used", []),
            "escalated": was_escalated,
        },
        "outcome": {
            "success": not state.get("last_error"),
            "output": state.get("run_output", "")[:2000],
            "summary": "",
        },
        "trajectory": state.get("trajectory", []),
        "metadata": {
            "agent": task.get("agent", os.environ.get("AGENT_NAME", "sandbox")),
            "backend": "langgraph",
            "tier": state.get("current_model", "unknown"),
            "category": task.get("category", "coding"),
            "expert_used": task.get("agent"),
            "available_experts": _list_available_experts() if task.get("agent") else [],
        },
    }

    # Write CSPO entry
    results_dir = os.environ.get("RESULTS_DIR", "/workspace/results")
    os.makedirs(results_dir, exist_ok=True)
    cspo_path = os.path.join(results_dir, "cspo-entry.json")
    with open(cspo_path, "w") as f:
        json.dump(cspo_entry, f, indent=2)

    return {"success": not state.get("last_error")}


async def cleanup_sandbox(state: SandboxState) -> dict:
    """Cleanup workspace."""
    # Nothing to clean — sandbox lifecycle managed by agent-runner
    return {}


# ---------------------------------------------------------------------------
# Build the graph
# ---------------------------------------------------------------------------

def build_graph():
    """Construct the LangGraph StateGraph for sandbox execution."""
    graph = StateGraph(SandboxState)

    graph.add_node("create", create_sandbox)
    graph.add_node("prepare", prepare_sandbox)
    graph.add_node("run", run_command)
    graph.add_node("retry", retry_node)
    graph.add_node("escalate", escalate_node)
    graph.add_node("inspect", inspect_results)
    graph.add_node("cleanup", cleanup_sandbox)

    graph.set_entry_point("create")
    graph.add_edge("create", "prepare")
    graph.add_edge("prepare", "run")
    graph.add_conditional_edges("run", decide_next, {
        "inspect": "inspect",
        "retry": "retry",
        "escalate": "escalate",
    })
    graph.add_edge("retry", "run")
    graph.add_edge("escalate", "run")
    graph.add_edge("inspect", "cleanup")
    graph.add_edge("cleanup", END)

    return graph


def compile_graph():
    """Compile graph with checkpointing for rollback support."""
    checkpointer = MemorySaver()
    graph = build_graph()
    return graph.compile(checkpointer=checkpointer)


# ---------------------------------------------------------------------------
# Entry point — reads task.json (matching ADK pattern)
# ---------------------------------------------------------------------------

async def main():
    task_file = os.environ.get("TASK_FILE", "/workspace/results/task.json")

    if not os.path.exists(task_file):
        print(f"[sandbox_workflow] No task file at {task_file}")
        return

    with open(task_file) as f:
        task = json.load(f)

    execution_mode = task.get("execution_mode", os.environ.get("EXECUTION_MODE", "auto"))

    initial_state: SandboxState = {
        "task": task,
        "execution_mode": execution_mode,
        "sandbox_id": "",
        "sandbox_domain": os.environ.get("SANDBOX_DOMAIN", "172.17.0.1:8080"),
        "current_model": "",
        "escalation_index": 0,
        "attempt": 0,
        "max_attempts": task.get("max_attempts", 2),
        "run_output": "",
        "last_error": "",
        "success": False,
        "trajectory": [],
        "models_used": [],
    }

    app = compile_graph()
    config = {
        "configurable": {"thread_id": task.get("id", "default")},
        "recursion_limit": 50,
    }

    final_state = await app.ainvoke(initial_state, config=config)

    print(f"[sandbox_workflow] Done: success={final_state.get('success')}, "
          f"models={final_state.get('models_used')}, "
          f"escalated={final_state.get('escalation_index', 0) > 0}")


if __name__ == "__main__":
    asyncio.run(main())
