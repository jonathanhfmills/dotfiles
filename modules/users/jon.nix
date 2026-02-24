{ pkgs, lib, ... }:

{
  home.username = "jon";
  home.homeDirectory = "/home/jon";
  home.stateVersion = "25.11";
  programs.home-manager.enable = true;

  fonts.fontconfig.enable = true;

  programs.git = {
    enable = true;
    settings.user.name = "Jonathan Mills";
    settings.user.email = "";
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
      "desktop" = {
        hostname = "100.74.117.36";
        user = "jon";
      };
      "workstation" = {
        hostname = "100.95.201.10";
        user = "jon";
      };
      "portable" = {
        hostname = "portable";
        user = "jon";
      };
      "nas" = {
        hostname = "100.103.206.89";
        user = "jon";
      };
    };
    includes = [ "~/.ssh/config.d/*" ];
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
