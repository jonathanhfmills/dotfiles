"""UM policy training — DQN for UncertaintyManager model-selection.

Trains a DQN policy on historical CSPO entries to learn when to accept,
retry, or escalate. Replaces hardcoded confidence thresholds in decide_next().

Runs inside a code-interpreter sandbox (isolated, reproducible).
Triggered weekly or when enough new CSPO entries accumulate.
"""

import glob
import json
import os

import gymnasium as gym
import numpy as np
from gymnasium import spaces


class UMPolicyEnv(gym.Env):
    """Gymnasium env for UncertaintyManager training.

    Observations: task features extracted from CSPO entries.
    Actions: 0=accept (inspect), 1=retry, 2=escalate.
    Reward: CSPO outcome score (0-1).
    """

    metadata = {"render_modes": []}

    def __init__(self, cspo_entries: list[dict]):
        super().__init__()
        self.entries = cspo_entries
        self.current_idx = 0

        # Observation: [category_hash, escalation_index, attempt_count, output_length]
        self.observation_space = spaces.Box(
            low=np.array([0, 0, 0, 0], dtype=np.float32),
            high=np.array([1000, 10, 10, 100000], dtype=np.float32),
        )
        # Actions: accept, retry, escalate
        self.action_space = spaces.Discrete(3)

    def _get_obs(self) -> np.ndarray:
        entry = self.entries[self.current_idx]
        meta = entry.get("metadata", {})
        solution = entry.get("solution", {})
        outcome = entry.get("outcome", {})

        category = meta.get("category", "")
        category_hash = float(hash(category) % 1000)
        escalation = 1.0 if solution.get("escalated", False) else 0.0
        attempts = float(solution.get("attempts", 1))
        output_len = float(len(outcome.get("output", "")))

        return np.array([category_hash, escalation, attempts, output_len], dtype=np.float32)

    def reset(self, *, seed=None, options=None):
        super().reset(seed=seed)
        self.current_idx = self.np_random.integers(0, len(self.entries))
        return self._get_obs(), {}

    def step(self, action):
        entry = self.entries[self.current_idx]
        outcome = entry.get("outcome", {})
        solution = entry.get("solution", {})

        success = outcome.get("success", False)
        was_escalated = solution.get("escalated", False)

        # Reward logic:
        # - Correct accept on success: +1.0
        # - Unnecessary escalation on easy task: +0.3 (it worked, but wasteful)
        # - Correct escalation that led to success: +0.8
        # - Accept on failure: -1.0
        # - Retry on success: +0.2 (cautious but ok)
        if action == 0:  # accept
            reward = 1.0 if success else -1.0
        elif action == 1:  # retry
            reward = 0.2 if success else -0.5
        elif action == 2:  # escalate
            if was_escalated and success:
                reward = 0.8  # Correctly identified need for escalation
            elif success and not was_escalated:
                reward = 0.3  # Unnecessary escalation
            else:
                reward = -0.3  # Escalated but still failed

        # Move to next entry
        self.current_idx = (self.current_idx + 1) % len(self.entries)
        terminated = False
        truncated = self.current_idx == 0  # Wrapped around
        return self._get_obs(), reward, terminated, truncated, {}


def load_cspo_entries(scored_dir: str) -> list[dict]:
    """Load all scored CSPO entries from the trajectories directory."""
    entries = []
    for path in glob.glob(os.path.join(scored_dir, "*.json")):
        try:
            with open(path) as f:
                entry = json.load(f)
                if "outcome" in entry:
                    entries.append(entry)
        except (json.JSONDecodeError, IOError):
            continue
    return entries


def train_policy(entries: list[dict], output_dir: str, total_timesteps: int = 10000):
    """Train DQN policy on CSPO entries."""
    from stable_baselines3 import DQN
    from stable_baselines3.common.callbacks import EvalCallback

    env = UMPolicyEnv(entries)

    # Split for eval
    eval_entries = entries[:max(1, len(entries) // 10)]
    eval_env = UMPolicyEnv(eval_entries)

    os.makedirs(output_dir, exist_ok=True)

    eval_callback = EvalCallback(
        eval_env,
        best_model_save_path=output_dir,
        log_path=output_dir,
        eval_freq=max(500, total_timesteps // 20),
        deterministic=True,
    )

    model = DQN(
        "MlpPolicy",
        env,
        learning_rate=1e-4,
        buffer_size=min(len(entries) * 10, 50000),
        batch_size=32,
        gamma=0.99,
        exploration_fraction=0.3,
        verbose=1,
    )

    model.learn(total_timesteps=total_timesteps, callback=eval_callback)

    checkpoint_path = os.path.join(output_dir, "um_policy_dqn")
    model.save(checkpoint_path)

    # Training summary
    summary = {
        "total_entries": len(entries),
        "total_timesteps": total_timesteps,
        "checkpoint": f"{checkpoint_path}.zip",
    }
    with open(os.path.join(output_dir, "training_summary.json"), "w") as f:
        json.dump(summary, f, indent=2)

    print(f"[um_policy_training] Saved checkpoint to {checkpoint_path}.zip")
    return checkpoint_path


if __name__ == "__main__":
    scored_dir = os.environ.get(
        "SCORED_DIR",
        "/var/lib/orchestrator/shared/trajectories/scored/",
    )
    output_dir = os.environ.get("OUTPUT_DIR", "/workspace/results/checkpoints")
    timesteps = int(os.environ.get("TRAINING_TIMESTEPS", "10000"))

    entries = load_cspo_entries(scored_dir)
    if len(entries) < 10:
        print(f"[um_policy_training] Only {len(entries)} entries — need at least 10, skipping.")
    else:
        print(f"[um_policy_training] Training on {len(entries)} CSPO entries...")
        train_policy(entries, output_dir, total_timesteps=timesteps)
