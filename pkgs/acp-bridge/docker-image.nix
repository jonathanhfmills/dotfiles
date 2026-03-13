{ pkgs, acp-bridge, qwen-code }:

let
  # Python with pip for google-adk installation at container startup
  # ADK has 44+ deps including Google Cloud SDK — not practical to package natively
  pythonEnv = pkgs.python312.withPackages (ps: with ps; [
    pip
    setuptools
  ]);

  # Script to install google-adk + litellm on first run (cached in /home/agent/.local)
  adkBootstrap = pkgs.writeShellScriptBin "adk-bootstrap" ''
    if ! ${pythonEnv}/bin/python -c "import google.adk" 2>/dev/null; then
      echo "[adk-bootstrap] Installing google-adk + litellm..."
      ${pythonEnv}/bin/pip install --user --quiet google-adk litellm 2>&1 || true
    fi
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

    # Python runtime + ADK bootstrap (pip installs on first run)
    pythonEnv
    adkBootstrap

    # C++ runtime (libstdc++.so.6) — needed by litellm's tokenizers dependency
    pkgs.stdenv.cc.cc.lib

    # CA certs for HTTPS (ollama, OpenClaw, frontier APIs)
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
      "PATH=/home/agent/.local/bin:/usr/bin:/bin"
    ];
  };

  # Max 100 layers for Docker compatibility
  maxLayers = 100;
}
