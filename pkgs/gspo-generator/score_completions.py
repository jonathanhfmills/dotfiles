#!/usr/bin/env python3
"""Phase 2: Score completions using the 35B-A3B CPU teacher.

Reads completion groups from Phase 1, sends each to the 35B scorer,
and writes scored output in ms-swift GSPO format.

The teacher just outputs a score (1-10) for each completion — no full
response generation needed, so even at ~2-5 tok/s this is fast.

Output format (ms-swift GSPO):
    {"query": ..., "response_list": [...], "label_list": [...]}

Usage:
    python score_completions.py \
        --input-dir /var/lib/vllm/models/trajectories/scored \
        --scorer-url http://localhost:11435/v1
"""

import argparse
import json
import os
import sys
import time
from pathlib import Path

import openai

SCORING_PROMPT = """You are an expert evaluator. Score the following AI assistant response on a scale of 1-10 based on:
- Correctness and accuracy
- Helpfulness and completeness
- Clarity and coherence
- Following instructions precisely

Conversation context:
{prompt}

Assistant response to evaluate:
{response}

Output ONLY a single number from 1 to 10. Nothing else."""


def score_completion(
    client: openai.OpenAI,
    model_id: str,
    prompt_messages: list[dict],
    response_text: str,
) -> float:
    """Score a single completion using the 35B teacher. Returns 0-1 normalized score."""
    # Format prompt context as readable text
    prompt_text = "\n".join(
        f"{m['role'].upper()}: {m['content']}" for m in prompt_messages
    )

    try:
        result = client.chat.completions.create(
            model=model_id,
            messages=[{
                "role": "user",
                "content": SCORING_PROMPT.format(prompt=prompt_text, response=response_text),
            }],
            temperature=0.0,
            max_tokens=8,
        )
        score_text = (result.choices[0].message.content or "").strip()
        # Parse the numeric score
        score = float(score_text.split()[0].strip(".,;:"))
        return max(0.0, min(1.0, score / 10.0))  # normalize to 0-1
    except (ValueError, IndexError):
        print(f"Warning: could not parse score from: {score_text!r}", file=sys.stderr)
        return 0.5  # neutral fallback
    except Exception as e:
        print(f"Warning: scoring failed: {e}", file=sys.stderr)
        return 0.5


def format_prompt_as_query(messages: list[dict]) -> str:
    """Format prompt messages as a single query string for ms-swift."""
    # Use the last user message as the query
    for m in reversed(messages):
        if m["role"] == "user":
            return m["content"]
    return messages[0]["content"] if messages else ""


def main():
    parser = argparse.ArgumentParser(description="Score completions with 35B teacher for GSPO")
    parser.add_argument("--input-dir", required=True, help="Directory with completion .jsonl files")
    parser.add_argument("--scorer-url", default="http://localhost:11435/v1", help="Scorer API URL")
    parser.add_argument("--api-key", default="ollama", help="API key")
    parser.add_argument("--output-dir", default=None, help="Output directory (default: same as input)")
    args = parser.parse_args()

    output_dir = args.output_dir or args.input_dir
    os.makedirs(output_dir, exist_ok=True)

    client = openai.OpenAI(base_url=args.scorer_url, api_key=args.api_key)

    # Wait for scorer to be ready
    print("Waiting for scorer to be ready...")
    for attempt in range(60):
        try:
            models = client.models.list()
            model_id = models.data[0].id if models.data else "default"
            print(f"Scorer ready: {model_id}")
            break
        except Exception:
            if attempt % 10 == 0:
                print(f"  attempt {attempt + 1}/60...")
            time.sleep(5)
    else:
        print("ERROR: Scorer not ready after 5 minutes", file=sys.stderr)
        sys.exit(1)

    # Process completion files
    input_path = Path(args.input_dir)
    completion_files = sorted(input_path.glob("completions_*.jsonl"))

    if not completion_files:
        print("No completion files found. Exiting.")
        return

    total_scored = 0
    output_file = Path(output_dir) / f"gspo_scored_{int(time.time())}.jsonl"

    with open(output_file, "w") as out:
        for cfile in completion_files:
            print(f"Scoring {cfile.name}...")
            with open(cfile) as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue

                    record = json.loads(line)
                    prompt = record["prompt"]
                    completions = record["completions"]

                    # Score each completion
                    response_list = []
                    label_list = []

                    for comp in completions:
                        if comp.get("finish_reason") == "error" or not comp["content"]:
                            continue
                        score = score_completion(client, model_id, prompt, comp["content"])
                        response_list.append(comp["content"])
                        label_list.append(score)

                    if len(response_list) < 2:
                        continue  # GSPO needs at least 2 responses to rank

                    # ms-swift GSPO format
                    gspo_record = {
                        "query": format_prompt_as_query(prompt),
                        "response_list": response_list,
                        "label_list": label_list,
                    }
                    out.write(json.dumps(gspo_record) + "\n")
                    total_scored += 1

    print(f"Scored {total_scored} prompt groups → {output_file}")

    # Clean up raw completion files (scored data is the source of truth now)
    for cfile in completion_files:
        cfile.unlink()
        print(f"  cleaned up {cfile.name}")


if __name__ == "__main__":
    main()
