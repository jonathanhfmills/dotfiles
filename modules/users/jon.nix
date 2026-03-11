{ pkgs, lib, osConfig, ... }:

let
  hostname = osConfig.networking.hostName;
  qwenModel = {
    workstation = "qwen3.5:9b";
    nas = "qwen3.5";
  }.${hostname} or "qwen3.5:9b";
  qwenBaseUrl = {
    workstation = "http://localhost:11434/v1";
    nas = "http://localhost:11434/v1";
  }.${hostname} or "http://workstation:11434/v1";
in
{
  home.username = "jon";
  home.homeDirectory = "/home/jon";
  home.stateVersion = "25.11";
  programs.home-manager.enable = true;

  # 1Password SSH agent for the entire desktop session (not just bash).
  home.sessionVariables.SSH_AUTH_SOCK = "/home/jon/.1password/agent.sock";

  home.packages = [ pkgs.aw-watcher-bash ];

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

  # Qwen Code — per-host ollama routing.
  home.file.".qwen/settings.json".text = builtins.toJSON {
    modelProviders.openai = [{
      id = qwenModel;
      name = "Qwen 3.5 (${hostname} ollama)";
      envKey = "QWEN_API_KEY";
      baseUrl = qwenBaseUrl;
    }];
    security.auth.selectedType = "openai";
    model.name = qwenModel;
  };

  home.file.".continue/config.json".text = builtins.toJSON {
    models = [
      {
        title = "qwen3:14b (workstation)";
        provider = "ollama";
        model = "qwen3:14b";
        apiBase = "http://100.95.201.10:11434";
      }
      {
        title = "gemma3:12b (nas)";
        provider = "ollama";
        model = "gemma3:12b";
        apiBase = "http://100.87.216.16:11434";
      }
    ];
    tabAutocompleteModel = {
      title = "qwen3:14b";
      provider = "ollama";
      model = "qwen3:14b";
      apiBase = "http://100.95.201.10:11434";
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
