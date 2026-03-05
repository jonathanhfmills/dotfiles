{ ... }:

{
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "jon" "cosmick" ];
  };

  # Use 1Password SSH agent for all sessions (terminal, desktop, VSCode).
  environment.sessionVariables.SSH_AUTH_SOCK = "/home/jon/.1password/agent.sock";
}
