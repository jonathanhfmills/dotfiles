{ pkgs, lib, ... }:

{
  home.username = "jon";
  home.homeDirectory = "/home/jon";
  home.stateVersion = "25.11";
  programs.home-manager.enable = true;

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
      "/run/agenix/ssh-hosts"   # Fleet + client hosts (encrypted)
      "~/.ssh/config.d/*"
    ];
  };

  programs.bash = {
    enable = true;
    historySize = 10000;
    historyControl = [ "ignoredups" "erasedups" ];
    sessionVariables = {
      SSH_AUTH_SOCK = "$HOME/.1password/agent.sock";
    };
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

  home.file.".stignore".text = ''
    // Nix & home-manager managed
    .nix-profile
    .nix-defexpr
    .local/state/nix
    .local/state/home-manager
    .bash_profile
    .bashrc
    .profile
    .config/git
    .config/environment.d/10-home-manager.conf
    .config/mimeapps.list
    .config/cosmic
    .continue/config.json
    .vscode/extensions

    // Caches (all regeneratable)
    .cache

    // Large binaries
    .local/share/Steam
    .steam
    .steampath
    .steampid

    // Trash & downloads
    .local/share/Trash
    Downloads

    // Git-managed repos (use git, not syncthing)
    dotfiles

    // Machine-specific runtime state
    .gnupg
    .pki
    .pulse-cookie
    .local/share/gvfs-metadata
    .local/share/nautilus

    // Browser caches (keep profiles/bookmarks, skip caches)
    .config/google-chrome/**/Cache
    .config/google-chrome/**/Code Cache
    .config/google-chrome/**/Service Worker
    .config/google-chrome/**/GrShaderCache
    .config/chromium/**/Cache
    .config/chromium/**/Code Cache
    .config/chromium.bak

    // App caches
    .config/discord/Cache
    .config/discord/Code Cache
    .config/discord/GPUCache
    .config/Code/Cache
    .config/Code/CachedData
    .config/Code/CachedExtensions
    .config/Code/logs

    // Database locks (prevent corruption)
    *.sqlite-shm
    *.sqlite-wal
    *.lock

    // Misc temp
    *.tmp
    *.swp
    .ironclaw
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
