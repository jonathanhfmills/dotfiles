{ pkgs, ... }:

{
  home.username = "jon-private";
  home.homeDirectory = "/home/jon-private";
  home.stateVersion = "25.11";
  programs.home-manager.enable = true;

  fonts.fontconfig.enable = true;

  programs.bash = {
    enable = true;
    historySize = 10000;
    historyControl = [ "ignoredups" "erasedups" ];
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
