{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    nodejs_22
    python3
    playwright-test
    playwright-driver.browsers
  ];

  environment.sessionVariables = {
    PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
    PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
    PLAYWRIGHT_HOST_PLATFORM_OVERRIDE = "ubuntu-24.04";
  };
}
