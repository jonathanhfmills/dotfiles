{ pkgs, ... }:

{
  xsession.windowManager.i3 = {
    enable = true;
    config = {
      modifier = "Mod4";
      terminal = "${pkgs.alacritty}/bin/alacritty";
      startup = [
        { command = "${pkgs.vscode}/bin/code"; notification = false; }
        { command = "${pkgs.chromium}/bin/chromium"; notification = false; }
      ];
      bars = [{
        statusCommand = "${pkgs.i3status}/bin/i3status";
      }];
    };
  };

  home.packages = with pkgs; [ alacritty chromium ];
}
