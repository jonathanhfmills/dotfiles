#!/usr/bin/env python3
"""Phase 1: Generate K completions per prompt using the 9B GPU model.

Reads raw trajectory .jsonl files, extracts prompts, and generates K=4
completions for each. Output format matches ms-swift GSPO dataset schema.

Usage:
    python generate_completions.py \
        --input-dir /var/lib/vllm/models/trajectories/raw \
        --output-dir /var/lib/vllm/models/trajectories/scored \
        --model-url http://localhost:11434/v1 \
        --completions-per-prompt 4
"""

import argparse
import json
import os
import sys
import time
from pathlib import Path

import openai


def load_trajectories(input_dir: str) -> list[dict]:
    """Load raw trajectory JSONL files from input directory."""
    trajectories = []
    input_path = Path(input_dir)

    for jsonl_file in sorted(input_path.glob("*.jsonl")):
        with open(jsonl_file) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    traj = json.loads(line)
                    if "messages" in traj and len(traj["messages"]) > 0:
                        trajectories.append(traj)
                except json.JSONDecodeError:
                    print(f"Warning: skipping malformed line in {jsonl_file}", file=sys.stderr)

    return trajectories


def extract_prompt(traj: dict) -> list[dict]:
    """Extract the prompt messages (everything before the last assistant response)."""
    messages = traj["messages"]
    # Find the last user message — everything up to and including it is the prompt
    for i in range(len(messages) - 1, -1, -1):
        if messages[i]["role"] == "user":
            return messages[: i + 1]
    return messages[:1]  # fallback: just the first message


def generate_completions(
    client: openai.OpenAI,
    prompt_messages: list[dict],
    k: int,
    model: str,
) -> list[dict]:
    """Generate K completions for a given prompt."""
    completions = []
    for i in range(k):
        try:
            response = client.chat.completions.create(
                model=model,
                messages=prompt_messages,
                temperature=0.8,  # diversity for GSPO ranking
                max_tokens=4096,
                top_p=0.95,
            )
            content = response.choices[0].message.content or ""
            completions.append({
                "content": content,
                "index": i,
                "finish_reason": response.choices[0].finish_reason,
            })
        except Exception as e:
            print(f"Warning: completion {i} failed: {e}", file=sys.stderr)
            completions.append({
                "content": "",
                "index": i,
                "finish_reason": "error",
                "error": str(e),
            })
    return completions


def main():
    parser = argparse.ArgumentParser(description="Generate K completions per prompt for GSPO")
    parser.add_argument("--input-dir", required=True, help="Directory with raw trajectory .jsonl files")
    parser.add_argument("--output-dir", required=True, help="Directory for scored output .jsonl files")
    parser.add_argument("--model-url", default="http://localhost:11434/v1", help="OpenAI-compatible API base URL")
    parser.add_argument("--api-key", default="ollama", help="API key")
    parser.add_argument("--completions-per-prompt", type=int, default=4, help="Number of completions per prompt (K)")
    parser.add_argument("--max-prompts", type=int, default=0, help="Max prompts to process (0=all)")
    args = parser.parse_args()

    os.makedirs(args.output_dir, exist_ok=True)

    client = openai.OpenAI(base_url=args.model_url, api_key=args.api_key)

    # Discover model name
    models = client.models.list()
    model_id = models.data[0].id if models.data else "default"
    print(f"Using model: {model_id}")

    trajectories = load_trajectories(args.input_dir)
    if not trajectories:
        print("No trajectories found. Exiting.")
        return

    if args.max_prompts > 0:
        trajectories = trajectories[: args.max_prompts]

    print(f"Generating {args.completions_per_prompt} completions for {len(trajectories)} prompts...")

    output_file = Path(args.output_dir) / f"completions_{int(time.time())}.jsonl"
    generated = 0

    with open(output_file, "w") as out:
        for i, traj in enumerate(trajectories):
            prompt = extract_prompt(traj)
            completions = generate_completions(client, prompt, args.completions_per_prompt, model_id)

            record = {
                "prompt": prompt,
                "completions": completions,
                "source": traj.get("source", "unknown"),
                "timestamp": time.time(),
            }
            out.write(json.dumps(record) + "\n")
            generated += 1

            if (i + 1) % 10 == 0:
                print(f"  {i + 1}/{len(trajectories)} prompts done")

    print(f"Generated completions for {generated} prompts → {output_file}")


if __name__ == "__main__":
    main()
