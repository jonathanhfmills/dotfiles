#!/usr/bin/env python3
"""Atropos RL Environment for Brain/Engineer/Grunt architecture.

Extends HermesAgentBaseEnv to generate tool-calling trajectories across
all three tiers. The MoE evaluator (35B-A3B on NAS CPU) provides
reward/punishment scoring for the RL training signal.

Usage with Atropos:
    python -m atropos.runner --env claw-army-env:ClawArmyEnv \
        --model Qwen/Qwen3.5-4B --reward-model Qwen/Qwen3.5-35B-A3B

Two-path training signal:
    - Local trajectories: qwen-code + Qwen-Agent ATIC
    - Frontier trajectories: claude/gemini/codex with native ATIC
    - Gap between them IS the training signal
"""
import json
import os
import time
import urllib.request
from dataclasses import dataclass, field

# Atropos environment base class
try:
    from atropos.environments.base import BaseEnv
except ImportError:
    # Fallback for standalone testing
    class BaseEnv:
        pass


EVALUATOR_URL = os.environ.get("EVALUATOR_URL", "http://wanda:11435/v1")
EVALUATOR_MODEL = os.environ.get("EVALUATOR_MODEL", "Qwen/Qwen3.5-35B-A3B")
EVALUATOR_API_KEY = os.environ.get("EVALUATOR_API_KEY", "ollama")
TRAJECTORY_DIR = os.environ.get(
    "TRAJECTORY_DIR", "/var/lib/orchestrator/shared/trajectories"
)


@dataclass
class TrajectoryEntry:
    """A single step in an agent trajectory."""
    tool: str
    input: dict
    output: str
    backend: str  # qwen-agent-atic, nullclaw-grunt, acp-qwen-code, frontier-*
    timestamp: float = field(default_factory=time.time)
    model: str = ""
    tier: str = ""  # classifier, medium, high, scorer, expert, frontier


def evaluate_with_moe(trajectory: list[dict], evaluator_url: str = EVALUATOR_URL,
                      model: str = EVALUATOR_MODEL) -> float:
    """Score a trajectory using the MoE evaluator (35B-A3B).

    Returns score 0-10. Used as reward signal for RL training.
    The evaluator runs on NAS CPU (~2-5 tok/s) — only for scoring,
    never for task completion.
    """
    trajectory_text = json.dumps(trajectory, indent=2)

    prompt = f"""Score this agent trajectory on a scale of 0-10.

Criteria:
1. Task completion — did it finish the work?
2. Efficiency — minimal unnecessary steps?
3. Tool selection — appropriate tools for each step?
4. Output quality — correct, well-formatted result?
5. Tier selection — was the right model tier used for each step?

Respond with ONLY: {{"score": <number>, "reason": "<brief>"}}

Trajectory:
{trajectory_text[:8000]}"""

    try:
        request_body = json.dumps({
            "model": model,
            "messages": [{"role": "user", "content": prompt}],
            "temperature": 0.1,
            "max_tokens": 200,
        }).encode()

        req = urllib.request.Request(
            f"{evaluator_url}/chat/completions",
            data=request_body,
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {EVALUATOR_API_KEY}",
            },
        )

        with urllib.request.urlopen(req, timeout=120) as resp:
            result = json.loads(resp.read())
            content = result["choices"][0]["message"]["content"]
            parsed = json.loads(content)
            return float(parsed.get("score", 0))
    except Exception:
        return 0.0


class ClawArmyEnv(BaseEnv):
    """RL environment for the Brain/Engineer/Grunt architecture.

    Generates tool-calling trajectories across all three tiers.
    Reward = MoE evaluator score (35B-A3B on NAS CPU, normalized to [0,1]).

    The environment captures both local and frontier trajectories.
    The gap between local and frontier scores IS the training signal.
    """

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.trajectory_dir = TRAJECTORY_DIR
        os.makedirs(self.trajectory_dir, exist_ok=True)
        os.makedirs(os.path.join(self.trajectory_dir, "scored"), exist_ok=True)

    def get_task_prompts(self) -> list[str]:
        """Return task prompts for trajectory generation.

        Sources:
        1. Queued tasks from /var/lib/orchestrator/shared/queue/
        2. Previously failed tasks (for retry training)
        3. Synthetic tasks from task templates
        """
        prompts = []

        # Collect from queue results (completed tasks have prompts)
        results_dir = "/var/lib/orchestrator/shared/queue/results"
        if os.path.exists(results_dir):
            for fname in os.listdir(results_dir):
                if fname.endswith(".done.json"):
                    path = os.path.join(results_dir, fname)
                    try:
                        with open(path) as f:
                            task = json.load(f)
                            prompt = task.get("prompt", "")
                            if prompt:
                                prompts.append(prompt)
                    except (json.JSONDecodeError, OSError):
                        continue

        # Synthetic task templates for training diversity
        if not prompts:
            prompts = [
                "Write a Python function that validates email addresses",
                "Create a bash script to monitor disk usage and alert when above 80%",
                "Review this code for security vulnerabilities",
                "Summarize the key changes in the latest commit",
                "Write unit tests for a REST API endpoint",
            ]

        return prompts

    def compute_reward(self, trajectory: list[dict]) -> float:
        """Compute reward using MoE evaluator.

        Score is normalized to [0, 1] for RL training.
        Trajectories scoring >= 7.0 (raw) are saved for QLoRA training.
        """
        raw_score = evaluate_with_moe(trajectory)
        normalized = raw_score / 10.0

        # Save scored trajectory
        entry = {
            "trajectory": trajectory,
            "score": raw_score,
            "normalized_reward": normalized,
            "timestamp": time.time(),
            "evaluator": EVALUATOR_MODEL,
        }

        scored_dir = os.path.join(self.trajectory_dir, "scored")
        fname = f"traj_{int(time.time())}_{raw_score:.1f}.json"
        with open(os.path.join(scored_dir, fname), "w") as f:
            json.dump(entry, f, indent=2)

        return normalized

    def save_trajectory(self, trajectory: list[dict], backend: str,
                        model: str, task_prompt: str):
        """Save a raw trajectory for later scoring and training."""
        entry = {
            "trajectory": trajectory,
            "backend": backend,
            "model": model,
            "task_prompt": task_prompt,
            "timestamp": time.time(),
        }

        fname = f"raw_{backend}_{int(time.time())}.json"
        with open(os.path.join(self.trajectory_dir, fname), "w") as f:
            json.dump(entry, f, indent=2)


if __name__ == "__main__":
    # Standalone test
    env = ClawArmyEnv()
    prompts = env.get_task_prompts()
    print(f"Found {len(prompts)} task prompts")

    # Test MoE evaluator connection
    test_traj = [{"tool": "read_file", "input": {"path": "test.py"}, "output": "ok"}]
    score = evaluate_with_moe(test_traj)
    print(f"MoE evaluator score: {score}/10")
