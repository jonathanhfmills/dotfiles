#!/usr/bin/env python3
"""Phase 4: MIPRO prompt optimization using scored examples.

Optimizes prompts and few-shot examples via Bayesian search.
No gradients — ~800 API calls to the 9B model. 15-30 min.
Runs after GSPO training with the freshly-trained adapter loaded.

Usage:
    python optimize.py [--post-training]
"""

import argparse
import json
import sys
from pathlib import Path

try:
    import dspy
    from dspy.teleprompt import MIPROv2
except ImportError:
    print("ERROR: dspy not installed. Run: pip install dspy", file=sys.stderr)
    sys.exit(1)

SCORED_DIR = "/var/lib/vllm/models/trajectories/scored"
OUTPUT_DIR = "/var/lib/vllm/models/dspy"


class AgentTask(dspy.Module):
    """Agent task module for prompt optimization."""

    def __init__(self):
        self.reason = dspy.ChainOfThought("task_description -> plan, tool_calls, result")

    def forward(self, task_description):
        return self.reason(task_description=task_description)


def load_scored_examples() -> list[dspy.Example]:
    """Load scored GSPO examples as DSPy training examples."""
    examples = []
    scored_path = Path(SCORED_DIR)

    for jsonl_file in sorted(scored_path.glob("gspo_scored_*.jsonl")):
        with open(jsonl_file) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                record = json.loads(line)

                # Use the highest-scored response as the expected output
                if not record.get("response_list") or not record.get("label_list"):
                    continue

                best_idx = max(range(len(record["label_list"])), key=lambda i: record["label_list"][i])
                best_score = record["label_list"][best_idx]

                # Only use high-quality examples (score > 0.7)
                if best_score < 0.7:
                    continue

                examples.append(dspy.Example(
                    task_description=record["query"],
                    result=record["response_list"][best_idx],
                ).with_inputs("task_description"))

    return examples


def similarity(pred_result: str, expected: str) -> float:
    """Simple token-overlap similarity metric."""
    if not pred_result or not expected:
        return 0.0
    pred_tokens = set(pred_result.lower().split())
    expected_tokens = set(expected.lower().split())
    if not expected_tokens:
        return 0.0
    overlap = pred_tokens & expected_tokens
    return len(overlap) / len(expected_tokens)


def metric(example, pred, trace=None):
    """Evaluation metric: token overlap with known-good responses."""
    return similarity(pred.result, example.result) >= 0.5


def main():
    parser = argparse.ArgumentParser(description="DSPy/MIPRO prompt optimization")
    parser.add_argument("--post-training", action="store_true", help="Run after GSPO training")
    parser.add_argument("--model-url", default="http://localhost:11434/v1", help="Model API URL")
    parser.add_argument("--api-key", default="ollama", help="API key")
    parser.add_argument("--num-trials", type=int, default=20, help="MIPRO optimization trials")
    args = parser.parse_args()

    # Configure DSPy with the local 9B model
    qwen = dspy.LM(
        model="openai/Qwen3.5-9B",
        api_base=args.model_url,
        api_key=args.api_key,
    )
    dspy.configure(lm=qwen)

    trainset = load_scored_examples()
    if len(trainset) < 5:
        print(f"Only {len(trainset)} examples (need 5+). Skipping optimization.")
        return

    print(f"Optimizing with {len(trainset)} scored examples, {args.num_trials} trials...")

    optimizer = MIPROv2(metric=metric, auto="medium")
    optimized = optimizer.compile(
        student_program=AgentTask(),
        trainset=trainset,
        num_trials=args.num_trials,
    )

    output_path = Path(OUTPUT_DIR)
    output_path.mkdir(parents=True, exist_ok=True)
    output_file = output_path / "optimized_agent.json"
    optimized.save(str(output_file))

    print(f"Optimized prompts saved to {output_file}")


if __name__ == "__main__":
    main()
