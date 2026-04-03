{ pkgs, acp-bridge, qwen-code, hermes-agent }:

let
  # Python with LangGraph stack baked in (sandbox egress blocks PyPI)
  # google-adk still installed at runtime via adk-bootstrap (44+ deps including Google Cloud SDK)
  pythonEnv = pkgs.python312.withPackages (ps: with ps; [
    pip
    setuptools
    langgraph
    langchain-openai
    langchain-anthropic
  ]);

  # Script to install google-adk + litellm on first run (cached in /home/agent/.local)
  adkBootstrap = pkgs.writeShellScriptBin "adk-bootstrap" ''
    if ! ${pythonEnv}/bin/python -c "import google.adk" 2>/dev/null; then
      echo "[adk-bootstrap] Installing google-adk + litellm..."
      ${pythonEnv}/bin/pip install --user --quiet google-adk litellm rl-rock 2>&1 \
        || ${pythonEnv}/bin/pip install --break-system-packages --quiet google-adk litellm rl-rock 2>&1 \
        || echo "[adk-bootstrap] Warning: pip install failed (network may be restricted)"
    fi
  '';

  # LangGraph workflows — bundled into container
  langgraphWorkflows = pkgs.runCommand "langgraph-workflows" {} ''
    mkdir -p $out/opt/workflows/langgraph
    cp ${../../workflows/langgraph/sandbox_workflow.py} $out/opt/workflows/langgraph/sandbox_workflow.py
    cp ${../../workflows/langgraph/um_policy_training.py} $out/opt/workflows/langgraph/um_policy_training.py
  '';

  # Custom MCP servers — bundled into a single derivation
  mcpServers = pkgs.runCommand "mcp-servers" {} ''
    mkdir -p $out/opt/mcp-servers
    cp ${../../pkgs/mcp-servers/dispatch.py} $out/opt/mcp-servers/dispatch.py
    cp ${../../pkgs/mcp-servers/escalation.py} $out/opt/mcp-servers/escalation.py
    cp ${../../pkgs/mcp-servers/memory.py} $out/opt/mcp-servers/memory.py
    cp ${../../pkgs/mcp-servers/sandbox.py} $out/opt/mcp-servers/sandbox.py
  '';

  # /etc/passwd + /etc/group + home dir — required by Node.js os.userInfo()
  passwdEtc = pkgs.runCommand "passwd-etc" {} ''
    mkdir -p $out/etc $out/home/agent $out/tmp $out/workspace
    echo 'root:x:0:0:root:/root:/bin/bash' > $out/etc/passwd
    echo 'agent:x:1000:1000:agent:/home/agent:/bin/bash' >> $out/etc/passwd
    echo 'root:x:0:' > $out/etc/group
    echo 'agent:x:1000:' >> $out/etc/group
  '';
in
pkgs.dockerTools.buildLayeredImage {
  name = "acp-reasoning";
  tag = "latest";

  contents = with pkgs; [
    # ACP bridge + CLI reasoning engine
    acp-bridge
    qwen-code

    # Node.js runtime (bridge is ESM)
    nodejs_22

    # Tools available inside the reasoning container
    ripgrep
    git
    bashInteractive
    coreutils
    curl
    jq

    # Hermes Agent — baked in (hermes, hermes-agent, hermes-acp binaries)
    hermes-agent

    # Python runtime + bootstrap (pip installs google-adk on first run)
    pythonEnv
    adkBootstrap

    # MCP servers
    mcpServers

    # LangGraph workflows
    langgraphWorkflows

    # C++ runtime (libstdc++.so.6) — needed by litellm's tokenizers dependency
    pkgs.stdenv.cc.cc.lib

    # CA certs for HTTPS (vLLM, OpenClaw, frontier APIs)
    cacert

    # User/group files for Node.js os.userInfo()
    passwdEtc
  ];

  config = {
    Entrypoint = [ "${pkgs.nodejs_22}/bin/node" "${acp-bridge}/lib/acp-bridge/acp-bridge.mjs" ];
    WorkingDir = "/workspace";
    Env = [
      "ACP_CLI_COMMAND=qwen --acp --auth-type=openai"
      "QWEN_API_KEY=ollama"
      "HOME=/home/agent"
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "NODE_EXTRA_CA_CERTS=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "PYTHONUSERBASE=/home/agent/.local"
      "LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib"
      "MCP_SERVERS_DIR=/opt/mcp-servers"
      "PATH=/home/agent/.local/bin:/usr/bin:/bin"
    ];
  };

  # Max 100 layers for Docker compatibility
  maxLayers = 100;
}
