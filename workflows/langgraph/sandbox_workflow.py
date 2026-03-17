"""LangGraph universal execution engine — sandbox workflow.

Replaces per-backend execution with a StateGraph that dynamically selects
models per-node based on confidence, cost, and task type.

Execution modes:
  auto (default): Local chain 0.8B → 4B → 9B, no API costs.
  claude-code:    Claude CLI end-to-end in sandbox (future).
  gemini:         Gemini CLI end-to-end in sandbox (future).
  mixed:          Qwen cheap nodes + frontier quality nodes (future).

Every escalation generates CSPO training data for the RL loop.
"""

import asyncio
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
    """Execute the task command inside the sandbox."""
    t0 = time.monotonic()
    task = state["task"]
    mode = state.get("execution_mode", "auto")

    model_key = get_model_for_node("run", mode, state)
    command = task.get("command", "echo 'no command'")

    # Use fallback command on retry
    if state.get("attempt", 0) > 0 and task.get("fallback_command"):
        command = task["fallback_command"]

    # Future: frontier CLI dispatch
    if model_key == "claude-code":
        command = f'npm i -g @anthropic-ai/claude-code@latest && claude "{command}"'
    elif model_key == "gemini-cli":
        command = f'npm i -g @google/gemini-cli@latest && gemini "{command}"'

    run_output = ""
    last_error = ""
    try:
        proc = await asyncio.create_subprocess_shell(
            command,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=300)
        run_output = (stdout or b"").decode() + (stderr or b"").decode()
        if proc.returncode != 0:
            last_error = f"exit code {proc.returncode}: {(stderr or b'').decode()}"
    except asyncio.TimeoutError:
        last_error = "command timed out after 300s"
    except Exception as e:
        last_error = str(e)

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
            "error": last_error or None,
        }],
    }


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
            "agent": os.environ.get("AGENT_NAME", "sandbox"),
            "backend": "langgraph",
            "tier": state.get("current_model", "unknown"),
            "category": task.get("category", "coding"),
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
