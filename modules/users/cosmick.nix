{ pkgs, lib, ... }:

{
  home.username = "cosmick";
  home.homeDirectory = "/home/cosmick";
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
    matchBlocks."*" = {
      extraOptions = {
        IdentityAgent = "~/.1password/agent.sock";
      };
    };
  };

  programs.bash = {
    enable = true;
    historySize = 10000;
    historyControl = [ "ignoredups" "erasedups" ];
    sessionVariables = {
      SSH_AUTH_SOCK = "$HOME/.1password/agent.sock";
    };
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
