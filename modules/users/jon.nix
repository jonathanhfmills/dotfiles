{ pkgs, lib, osConfig, ... }:

let
  hostname = osConfig.networking.hostName;
  isAgentHost = hostname == "workstation" || hostname == "nas";
  qwenModel = {
    workstation = "Qwen/Qwen3.5-4B";
    nas = "Qwen/Qwen3.5-9B";
  }.${hostname} or "Qwen/Qwen3.5-9B";
  qwenBaseUrl = {
    workstation = "http://localhost:11434/v1";
    nas = "http://localhost:11434/v1";
  }.${hostname} or "http://wanda:11434/v1";
in
{
  home.username = "jon";
  home.homeDirectory = "/home/jon";
  home.stateVersion = "25.11";
  programs.home-manager.enable = true;

  # 1Password SSH agent for the entire desktop session (not just bash).
  home.sessionVariables.SSH_AUTH_SOCK = "/home/jon/.1password/agent.sock";

  home.packages = [
    pkgs.aw-watcher-bash
    pkgs.nodePackages.intelephense  # php-lsp plugin dependency
  ];

  fonts.fontconfig.enable = true;

  programs.git = {
    enable = true;
    lfs.enable = true;
    settings.user.name = "Jonathan Mills";
    settings.user.email = "jon@cosmickmedia.com";
    settings.gpg.ssh.program = "${pkgs._1password-gui}/share/1password/op-ssh-sign";
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      "*" = {
        extraOptions = {
          IdentityAgent = "~/.1password/agent.sock";
        };
      };
    };
    includes = [
      "~/.ssh/config.d/*"
    ];
  };

  programs.bash = {
    enable = true;
    historySize = 10000;
    historyControl = [ "ignoredups" "erasedups" ];
    shellAliases = {
      claude = "command claude --dangerously-skip-permissions";
      qwen = "QWEN_API_KEY=ollama command qwen --auth-type=openai";
      qwen-acp = "QWEN_API_KEY=ollama command qwen --acp --auth-type=openai";
    };
    initExtra = ''
      if command -v tmux &>/dev/null && [ -z "$TMUX" ] && [[ $- == *i* ]] && [ -z "$INSIDE_EMACS" ] && [ -z "$VSCODE_RESOLVING_ENVIRONMENT" ]; then
        tmux new-session -A -s main && exit
      fi

      __aw_prompt_command() {
        local exit_code=$?
        local last_cmd
        last_cmd=$(HISTTIMEFORMAT= history 1 | sed 's/^[ ]*[0-9]*[ ]*//')
        if [ -n "$last_cmd" ]; then
          aw-watcher-bash "$last_cmd" "$PWD" "$exit_code" &>/dev/null & disown
        fi
      }
      PROMPT_COMMAND="__aw_prompt_command;$PROMPT_COMMAND"
    '';
  };

  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        # Remote development.
        ms-vscode-remote.remote-ssh
        ms-vscode-remote.remote-containers
        ms-vscode.remote-explorer

        # Nix.
        jnoortheen.nix-ide

        # Git.
        eamodio.gitlens

        # Editor.
        esbenp.prettier-vscode
        editorconfig.editorconfig
        usernamehw.errorlens
        streetsidesoftware.code-spell-checker

        # AI.
        anthropic.claude-code
        continue.continue

        # Docker.
        ms-azuretools.vscode-docker

        # Activity tracking.
        (pkgs.vscode-utils.extensionFromVscodeMarketplace {
          publisher = "activitywatch";
          name = "aw-watcher-vscode";
          version = "0.5.0";
          sha256 = "0nvw8pp6xaqs6w2zz3dr0vlrrpd6wcgh6jc5bp5ld92p0f34idrs";
        })
      ];
      userSettings = {
        "editor.formatOnSave" = true;
        "editor.minimap.enabled" = false;
        "editor.tabSize" = 2;
        "files.trimTrailingWhitespace" = true;
        "files.insertFinalNewline" = true;
        "nix.enableLanguageServer" = true;
        "nix.serverPath" = "${pkgs.nil}/bin/nil";
        "remote.SSH.configFile" = "~/.ssh/config";
        "remote.SSH.enableDynamicForwarding" = false;
        "remote.SSH.useLocalServer" = false;
      };
    };
  };

  # Claude Code — ActivityWatch hook for tool usage tracking.
  home.file.".claude/hooks/aw-heartbeat.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      INPUT=$(cat)
      TOOL=$(echo "$INPUT" | jq -r '.tool_name')
      COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // .tool_input.file_path // empty')
      [ -z "$COMMAND" ] && exit 0

      CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
      HOST=$(hostname)
      BUCKET_ID="aw-watcher-claude-code_$HOST"
      AW_URL="http://localhost:5600/api/0"
      FLAG="/tmp/.aw-watcher-claude-code-init-$HOST"

      if [ ! -f "$FLAG" ]; then
        curl -s -o /dev/null -X POST "$AW_URL/buckets/$BUCKET_ID" \
          -H "Content-Type: application/json" \
          -d "{\"client\": \"aw-watcher-claude-code\", \"type\": \"currentwindow\", \"hostname\": \"$HOST\"}" \
          && touch "$FLAG"
      fi

      TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
      EVENT=$(jq -n \
        --arg title "$TOOL: $COMMAND" \
        --arg app "Claude Code" \
        --arg tool "$TOOL" \
        --arg command "$COMMAND" \
        --arg cwd "$CWD" \
        --arg timestamp "$TIMESTAMP" \
        '{
          timestamp: $timestamp,
          duration: 0,
          data: {
            title: $title,
            app: $app,
            tool: $tool,
            command: $command,
            cwd: $cwd
          }
        }')

      curl -s -o /dev/null -X POST "$AW_URL/buckets/$BUCKET_ID/heartbeat?pulsetime=120" \
        -H "Content-Type: application/json" \
        -d "$EVENT"
    '';
  };

  home.file.".claude/settings.json".text = builtins.toJSON {
    skipDangerousModePermissionPrompt = true;
    autoDreamEnabled = true;
    hooks = {
      PostToolUse = [
        {
          matcher = "Bash|Edit|Write|Read|Grep|Glob";
          hooks = [
            {
              type = "command";
              command = "~/.claude/hooks/aw-heartbeat.sh";
            }
          ];
        }
      ];
    };
  };

  # Qwen Code — per-host vLLM routing + fleet config.
  # Sampling params tuned for 4-bit quantization stability (anti-loop)
  home.file.".qwen/settings.json".text = builtins.toJSON ({
    modelProviders.openai = [{
      id = qwenModel;
      name = "Qwen 3.5 (${hostname} vLLM)";
      envKey = "QWEN_API_KEY";
      baseUrl = qwenBaseUrl;
    }];
    security.auth.selectedType = "openai";
    model.name = qwenModel;
    model.parameters = {
      temperature = 0.7;
      top_p = 0.9;
      min_p = 0.05;
      frequency_penalty = 1.1;
      repeat_last_n = 64;
    };
    general.enableAutoUpdate = false;
    privacy.usageStatisticsEnabled = false;
    telemetry.enabled = false;
  } // lib.optionalAttrs isAgentHost {
    tools.approvalMode = "yolo";
    output.format = "json";
  });

  # Qwen Code — global context loaded for all sessions.
  home.file.".qwen/QWEN.md".text = ''
    # Fleet Context — ${hostname}

    You are running on **${hostname}**, part of Jon's NixOS fleet.

    ## Host Inventory

    | Host | Tailscale IP | GPU | Model | Role |
    |------|-------------|-----|-------|------|
    | desktop | 100.74.117.36 | — | (remote) | Developer workstation |
    | workstation (Cosmo) | 100.87.216.16 | RTX 3080 10GB | Qwen3.5-4B (vLLM CUDA) | Agent compute |
    | nas (Wanda) | 100.95.201.10 | AMD 9070 XT 16GB | Qwen3.5-9B (vLLM ROCm) + 0.8B (CPU) | Orchestrator + agents |
    | laptop | — | — | (remote) | Developer portable |

    ## Escalation Stack

    0.8B (CPU) → 4B (RTX 3080) → 9B (9070 XT) → 397B-A17B (OpenRouter) → Claude Opus 4.6 (break-glass)

    Solutions from higher tiers are captured for distillation back to local weights via unsloth.

    ## NixOS Conventions

    - Nix flake at `~/dotfiles` manages all hosts
    - Disko for declarative disk layouts
    - SSH key-only auth via 1Password (`jon@nixos-fleet`)
    - LTS kernel on ZFS hosts, latest otherwise
    - `systemd.settings.Manager` not `systemd.extraConfig` (deprecated)

    ## NixOS Gotchas

    - .NET self-contained apps: use `dontFixup = true` + `buildFHSEnv` — `autoPatchelfHook` corrupts runtime
    - GTK3 tinysparql pulls system `libsqlite3.so` overriding SQLCipher — fix with `LD_PRELOAD`

    ## Git Workflow

    - Feature branches, PRs to main
    - Commit messages: imperative, concise
    - Never force-push to main

    ## Self-Learning

    After completing a task, check your MEMORY.md. If you learned something non-obvious
    (a gotcha, a pattern that worked, a tool quirk), append it under the right heading.
    Keep entries concise — one line per lesson.
  '';

  home.file.".continue/config.json".text = builtins.toJSON {
    models = [
      {
        title = "Qwen3.5-9B (NAS vLLM)";
        provider = "openai";
        model = "Qwen/Qwen3.5-9B";
        apiBase = "http://100.95.201.10:11434/v1";
        apiKey = "ollama";
      }
      {
        title = "Qwen3.5-0.8B (NAS CPU)";
        provider = "openai";
        model = "Qwen/Qwen3.5-0.8B";
        apiBase = "http://100.95.201.10:11435/v1";
        apiKey = "ollama";
      }
    ];
    tabAutocompleteModel = {
      title = "Qwen3.5-0.8B (NAS CPU)";
      provider = "openai";
      model = "Qwen/Qwen3.5-0.8B";
      apiBase = "http://100.95.201.10:11435/v1";
      apiKey = "ollama";
    };
    tabAutocompleteOptions = {
      useCopyBuffer = false;
      maxPromptTokens = 1024;
    };
  };

  programs.tmux = {
    enable = true;
    terminal = "tmux-256color";
    historyLimit = 50000;
    escapeTime = 10;
    mouse = true;
    plugins = [
    ];
  };

  # Skills — copy /nix skill from dotfiles to user scope on every rebuild.
  # The dotfiles repo is the gitagent monorepo; skills/nix/ is the source of truth.
  home.activation.skillsSetup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.claude/skills/nix/references"
    cp ~/dotfiles/skills/nix/SKILL.md "$HOME/.claude/skills/nix/SKILL.md" 2>/dev/null || true
    cp ~/dotfiles/skills/nix/references/*.md "$HOME/.claude/skills/nix/references/" 2>/dev/null || true
  '';

  # Claude Code plugins — fix execute bits and NixOS shebang on every activation.
  # Marketplace syncs and plugin updates reset permissions and restore #!/bin/bash
  # which breaks on NixOS (no /bin/bash). Both are patched here idempotently.
  home.activation.claudePluginPermissions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    find "$HOME/.claude/plugins" -name "*.sh" 2>/dev/null | while read -r f; do
      chmod +x "$f"
      sed -i '1s|^#!/bin/bash$|#!/usr/bin/env bash|' "$f"
    done || true
  '';

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "google-chrome.desktop";
      "x-scheme-handler/http" = "google-chrome.desktop";
      "x-scheme-handler/https" = "google-chrome.desktop";
      "x-scheme-handler/about" = "google-chrome.desktop";
      "x-scheme-handler/unknown" = "google-chrome.desktop";
    };
  };
}
