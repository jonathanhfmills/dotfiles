"""ADK content pipeline — SequentialAgent: reader → writer → reviewer → deployer.

Equivalent to workflows/content-task.yaml but using ADK's dynamic orchestration.
Cosmo invokes this when the task needs LLM-driven routing between steps
(e.g., skip review if confidence is high, loop back to writer on rejection).

Usage: Called by Cosmo via ADK tool. Each agent step spawns an ACP session
with the appropriate CLI (qwen-code for local, claude for frontier).
"""

import os
import json

# ADK imports — available inside the reasoning container
from google.adk.agents import SequentialAgent, Agent
from google.adk.runners import InMemoryRunner
from google.genai import types

# LiteLLM integration for local vLLM models
from google.adk.models.lite_llm import LiteLlm


def get_model():
    """Get the ADK model — uses vLLM via LiteLLM by default."""
    model_name = os.environ.get("ADK_MODEL", "openai/Qwen/Qwen3.5-9B")
    return LiteLlm(model=model_name)


def make_agent(agent_id: str, description: str, instruction: str) -> Agent:
    """Create an ADK agent that delegates to an ACP session."""
    return Agent(
        name=agent_id,
        model=get_model(),
        description=description,
        instruction=instruction,
    )


# Pipeline agents — each corresponds to a Nullclaw agent with identity files
reader_agent = make_agent(
    "reader",
    "Researcher — gathers and verifies sources",
    "Research the given topic. Gather sources, verify facts, produce a structured "
    "summary with citations. Write findings to research_output in session state.",
)

writer_agent = make_agent(
    "writer",
    "Content author — drafts content from research",
    "Using the research findings from the previous step, draft content that matches "
    "the brief's tone, audience, and SEO requirements. Write draft to content_draft "
    "in session state.",
)

reviewer_agent = make_agent(
    "reviewer",
    "Quality gate — reviews for accuracy, tone, SEO",
    "Review the content draft for accuracy against research sources, tone consistency, "
    "SEO optimization, and readability. Provide approval or specific revision requests. "
    "Set review_status to 'approved' or 'revision_needed' in session state.",
)

deployer_agent = make_agent(
    "deployer",
    "Publisher — deploys approved content",
    "Deploy the approved content to the target platform. Verify the deployment "
    "succeeded and report the published URL.",
)

# Sequential pipeline — runs agents in order
content_pipeline = SequentialAgent(
    name="content_pipeline",
    sub_agents=[reader_agent, writer_agent, reviewer_agent, deployer_agent],
    description="Research → Write → Review → Publish content pipeline",
)


async def run_pipeline(task_prompt: str) -> str:
    """Execute the content pipeline with the given task prompt."""
    runner = InMemoryRunner(
        agent=content_pipeline,
        app_name="content_pipeline",
    )

    user_id = os.environ.get("AGENT_NAME", "cosmo")
    session = await runner.session_service.create_session(
        app_name="content_pipeline",
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

    task = os.environ.get("ADK_TASK", "")
    if not task:
        task_file = os.environ.get("ADK_TASK_FILE", "/workspace/task.json")
        if os.path.exists(task_file):
            with open(task_file) as f:
                data = json.load(f)
                task = data.get("prompt", data.get("description", ""))

    if task:
        result = asyncio.run(run_pipeline(task))
        print(result)
        # Write result for agent-runner to pick up
        with open("/workspace/results/adk-result.json", "w") as f:
            json.dump({"pipeline": "content", "result": result}, f)
    else:
        print("No task provided. Set ADK_TASK or ADK_TASK_FILE.")
