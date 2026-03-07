{ pkgs, lib, ... }:

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
