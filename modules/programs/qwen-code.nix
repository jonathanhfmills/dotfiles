{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.qwen-code ];

  environment.sessionVariables = {
    QWEN_API_KEY = "ollama";
  };
}
