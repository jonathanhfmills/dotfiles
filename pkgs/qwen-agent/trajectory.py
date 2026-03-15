#!/usr/bin/env python3
"""Trajectory capture for Qwen-Agent and ACP Bridge.

Instruments agent execution to log (action, observation, backend) tuples
as NDJSON for RL training. Both local and frontier trajectories are captured.

Output format (one JSON object per line):
{
    "tool": "read_file",
    "input": {"path": "src/main.py"},
    "output": "...",
    "backend": "qwen-agent-atic",
    "model": "Qwen/Qwen3.5-9B",
    "tier": "high",
    "timestamp": 1234567890.0,
    "task_id": "coder-abc12345",
    "duration_ms": 150
}
"""
import json
import os
import time


TRAJECTORY_DIR = os.environ.get(
    "TRAJECTORY_DIR", "/var/lib/orchestrator/shared/trajectories"
)


class TrajectoryLogger:
    """Append-only NDJSON trajectory logger.

    Usage:
        logger = TrajectoryLogger(task_id="coder-abc12345", backend="qwen-agent-atic")
        logger.log_tool_call("read_file", {"path": "test.py"}, "contents...", duration_ms=50)
        logger.close()
    """

    def __init__(self, task_id: str, backend: str, model: str = "", tier: str = ""):
        self.task_id = task_id
        self.backend = backend
        self.model = model
        self.tier = tier
        self.entries: list[dict] = []

        os.makedirs(TRAJECTORY_DIR, exist_ok=True)
        self.filepath = os.path.join(TRAJECTORY_DIR, f"{task_id}.ndjson")
        self._file = open(self.filepath, "a")

    def log_tool_call(self, tool: str, tool_input: dict, tool_output: str,
                      duration_ms: int = 0):
        """Log a single tool call."""
        entry = {
            "tool": tool,
            "input": tool_input,
            "output": tool_output[:2000],  # Truncate large outputs
            "backend": self.backend,
            "model": self.model,
            "tier": self.tier,
            "timestamp": time.time(),
            "task_id": self.task_id,
            "duration_ms": duration_ms,
        }
        self.entries.append(entry)
        self._file.write(json.dumps(entry) + "\n")
        self._file.flush()

    def get_trajectory(self) -> list[dict]:
        """Return all logged entries."""
        return self.entries

    def close(self):
        """Close the log file."""
        if self._file and not self._file.closed:
            self._file.close()

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.close()
