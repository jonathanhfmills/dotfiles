# Qwen-Agent — Python environment with Qwen-Agent + agent-sandbox SDK
# Installed via pip in Docker (not nix-native) — matches google-adk pattern
# Provides: qwen-agent[mcp] for MCP tool discovery, agent-sandbox for AIO Sandbox
{ pkgs }:

let
  pythonEnv = pkgs.python312.withPackages (ps: with ps; [
    pip
    setuptools
  ]);

  # Bootstrap script: pip install on first run (cached in /home/agent/.local)
  bootstrap = pkgs.writeShellScript "qwen-agent-bootstrap" ''
    if [ ! -f /home/agent/.local/.qwen-agent-installed ]; then
      echo "Installing qwen-agent + agent-sandbox..."
      pip install --user \
        "qwen-agent[mcp]>=0.0.34" \
        "agent-sandbox>=0.0.18" \
        "requests" \
        "pydantic" \
        2>&1 | tail -1
      touch /home/agent/.local/.qwen-agent-installed
    fi
  '';
in
{
  inherit pythonEnv bootstrap;
}
