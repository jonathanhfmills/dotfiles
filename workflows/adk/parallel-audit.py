"""ADK parallel audit — ParallelAgent: fan-out across multiple targets.

Cosmo invokes this when a task needs simultaneous work across multiple sites
or resources (e.g., "audit SEO on these 10 sites", "check security on 5 repos").

Each parallel branch gets its own ACP session with a reader agent.
Results are gathered and passed to a reviewer for synthesis.
"""

import os
import json

from google.adk.agents import ParallelAgent, SequentialAgent, Agent
from google.adk.runners import InMemoryRunner
from google.genai import types

# LiteLLM integration for local ollama models
from google.adk.models.lite_llm import LiteLlm


def get_model():
    """Get the ADK model — uses ollama via LiteLLM by default."""
    model_name = os.environ.get("ADK_MODEL", "ollama_chat/qwen3.5:9b")
    return LiteLlm(model=model_name)


def make_auditor(target: str, index: int) -> Agent:
    """Create an audit agent for a specific target."""
    return Agent(
        name=f"auditor_{index}",
        model=get_model(),
        description=f"Auditor for {target}",
        instruction=(
            f"Audit the target: {target}\n"
            "Perform a thorough analysis covering: accessibility, performance, "
            "SEO, security headers, and content quality. "
            "Produce a structured report with findings and severity ratings."
        ),
    )


def make_synthesizer() -> Agent:
    """Create the synthesis agent that combines parallel audit results."""
    return Agent(
        name="synthesizer",
        model=get_model(),
        description="Synthesizes parallel audit results into a unified report",
        instruction=(
            "You receive audit results from multiple parallel auditors. "
            "Combine them into a unified report with: "
            "1. Executive summary (top 3 critical findings across all targets) "
            "2. Per-target breakdown (sorted by severity) "
            "3. Recommended action items (prioritized) "
            "4. Patterns observed across targets"
        ),
    )


def build_audit_pipeline(targets: list[str]) -> SequentialAgent:
    """Build a parallel audit pipeline for the given targets."""
    auditors = [make_auditor(target, i) for i, target in enumerate(targets)]

    parallel_audit = ParallelAgent(
        name="parallel_audit",
        sub_agents=auditors,
        description=f"Fan-out audit across {len(targets)} targets",
    )

    synthesizer = make_synthesizer()

    return SequentialAgent(
        name="audit_pipeline",
        sub_agents=[parallel_audit, synthesizer],
        description="Parallel audit → synthesis pipeline",
    )


async def run_audit(targets: list[str], task_prompt: str) -> str:
    """Execute the parallel audit pipeline."""
    pipeline = build_audit_pipeline(targets)

    runner = InMemoryRunner(
        agent=pipeline,
        app_name="parallel_audit",
    )

    user_id = os.environ.get("AGENT_NAME", "cosmo")
    session = await runner.session_service.create_session(
        app_name="parallel_audit",
        user_id=user_id,
    )

    content = types.Content(
        role="user",
        parts=[types.Part.from_text(text=task_prompt)],
    )

    final_response = ""
    async for event in runner.run_async(
        user_id=user_id,
        session_id=session.id,
        new_message=content,
    ):
        if event.is_final_response() and event.content:
            for part in event.content.parts:
                if part.text:
                    final_response += part.text

    return final_response


if __name__ == "__main__":
    import asyncio

    task_file = os.environ.get("ADK_TASK_FILE", "/workspace/task.json")
    targets = []
    task_prompt = ""

    if os.path.exists(task_file):
        with open(task_file) as f:
            data = json.load(f)
            targets = data.get("targets", [])
            task_prompt = data.get("prompt", data.get("description", ""))

    # Fallback: env vars
    if not targets:
        targets_env = os.environ.get("ADK_TARGETS", "")
        if targets_env:
            targets = [t.strip() for t in targets_env.split(",")]

    if not task_prompt:
        task_prompt = os.environ.get("ADK_TASK", f"Audit these targets: {', '.join(targets)}")

    if targets:
        result = asyncio.run(run_audit(targets, task_prompt))
        print(result)
        with open("/workspace/results/adk-result.json", "w") as f:
            json.dump({"pipeline": "parallel_audit", "targets": targets, "result": result}, f)
    else:
        print("No targets provided. Set ADK_TARGETS or include targets in task.json.")
