# Hermes Agent — Brain tier orchestrator from NousResearch
# Installed via pip (complex dependency tree including openai, anthropic, litellm, etc.)
# ACP adapter exists in commit cc61f54 but not yet on main — install from that ref
{ pkgs }:

let
  pythonEnv = pkgs.python312.withPackages (ps: with ps; [
    pip
    setuptools
  ]);

  # Bootstrap: install hermes-agent with ACP + MCP support
  bootstrap = pkgs.writeShellScript "hermes-bootstrap" ''
    if [ ! -f /var/lib/hermes/.installed ]; then
      echo "Installing hermes-agent..."
      ${pythonEnv}/bin/pip install --target /var/lib/hermes/lib \
        "hermes-agent[acp,mcp]" \
        2>&1 | tail -5
      touch /var/lib/hermes/.installed
    fi
    export PYTHONPATH="/var/lib/hermes/lib:$PYTHONPATH"
  '';

  # Config template for Hermes
  configYaml = pkgs.writeText "hermes-config.yaml" ''
    model:
      default: "openai/Qwen/Qwen3.5-9B"
      provider: "auto"

    terminal:
      backend: "local"
      cwd: "/var/lib/orchestrator/shared"
      timeout: 300

    mcp_servers:
      sandbox:
        url: "http://localhost:8080/mcp"
        timeout: 120
      dispatch:
        command: "python"
        args: ["/opt/mcp-servers/dispatch.py"]
      escalation:
        command: "python"
        args: ["/opt/mcp-servers/escalation.py"]
      memory:
        command: "python"
        args: ["/opt/mcp-servers/memory.py"]
  '';
in
{
  inherit pythonEnv bootstrap configYaml;
}
