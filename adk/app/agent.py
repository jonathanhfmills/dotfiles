# ruff: noqa
import os
import subprocess
from pathlib import Path

from google.adk.agents import Agent
from google.adk.apps import App
from google.adk.models.lite_llm import LiteLlm
from google.adk.tools import LongRunningFunctionTool

AGENTS_DIR = Path.home() / ".agents"
DOTFILES_DIR = Path.home() / "dotfiles"


def deploy_stow(packages: list[str] | None = None) -> dict:
    """Deploy dotfiles stow packages to home directory.

    Args:
        packages: List of package names to stow. If None, stows all packages.

    Returns:
        dict with status and details of stowed packages.
    """
    if packages is None:
        packages = [
            d.name for d in DOTFILES_DIR.iterdir()
            if d.is_dir() and not d.name.startswith(".") and not d.name.startswith("_")
            and d.name not in ("wiki", "skills", "adk")
        ]
    results = []
    for pkg in packages:
        result = subprocess.run(
            ["stow", "-R", pkg, "--dir", str(DOTFILES_DIR), "--target", str(Path.home())],
            capture_output=True, text=True
        )
        results.append({
            "package": pkg,
            "success": result.returncode == 0,
            "output": result.stdout or result.stderr,
        })
    return {"stowed": results}


def list_agents() -> dict:
    """List all global agents in ~/.agents/.

    Returns:
        dict with agent names and their descriptions.
    """
    agents = []
    if AGENTS_DIR.exists():
        for d in sorted(AGENTS_DIR.iterdir()):
            if d.is_dir() and not d.name.startswith("."):
                yaml_path = d / "agent.yaml"
                description = ""
                if yaml_path.exists():
                    for line in yaml_path.read_text().splitlines():
                        if line.startswith("description:"):
                            description = line.split(":", 1)[1].strip().strip('"')
                            break
                agents.append({"name": d.name, "description": description})
    return {"agents": agents}


def get_agent_info(name: str) -> dict:
    """Get agent.yaml contents for a named global agent.

    Args:
        name: The agent name (directory name in ~/.agents/).

    Returns:
        dict with agent.yaml content or error.
    """
    agent_dir = AGENTS_DIR / name
    yaml_path = agent_dir / "agent.yaml"
    if not yaml_path.exists():
        return {"error": f"Agent '{name}' not found in {AGENTS_DIR}"}
    return {"name": name, "config": yaml_path.read_text()}


def query_wiki(query: str) -> dict:
    """Query the dotfiles wiki for information.

    Args:
        query: The question to ask the wiki.

    Returns:
        dict with wiki query result or instruction to run wiki agent.
    """
    wiki_dir = DOTFILES_DIR / "wiki"
    index_path = wiki_dir / "memory" / "wiki" / "index.md"
    if not wiki_dir.exists():
        return {"error": "Wiki not found at ~/dotfiles/wiki/"}
    index = index_path.read_text() if index_path.exists() else "Wiki index empty."
    return {
        "query": query,
        "wiki_index": index,
        "note": f"Run full wiki agent for detailed answers: npx @open-gitagent/gitagent@latest run -d {wiki_dir} -a claude -p '{query}'",
    }


def request_user_input(message: str) -> dict:
    """Request additional input from the user.

    Use this tool when you need more information from the user to complete a task.
    Calling this tool will pause execution until the user responds.

    Args:
        message: The question or clarification request to show the user.
    """
    return {"status": "pending", "message": message}


root_agent = Agent(
    name="root_agent",
    model=LiteLlm(model="anthropic/claude-sonnet-4-6"),
    description="Dotfiles orchestrator — manages stow packages, global agents, and wiki knowledge via A2A.",
    instruction=(
        "You are the dotfiles orchestrator. You manage the ~/dotfiles repository: "
        "deploy stow packages to set up the home directory, list and inspect global agents in ~/.agents/, "
        "and query the project wiki for configuration knowledge. "
        "For destructive operations like stow deploy, confirm with the user first."
    ),
    tools=[
        deploy_stow,
        list_agents,
        get_agent_info,
        query_wiki,
        LongRunningFunctionTool(func=request_user_input),
    ],
)

app = App(
    root_agent=root_agent,
    name="app",
)
