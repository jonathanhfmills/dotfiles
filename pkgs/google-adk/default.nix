# Google ADK has 44+ transitive dependencies including the entire Google Cloud SDK.
# Full Nix-native packaging is impractical — use pip inside the Docker image instead.
#
# This package provides a Python environment with google-adk installed via pip.
# Only used inside the acp-reasoning Docker image (not a host-level package).
{ pkgs }:

pkgs.python312.withPackages (ps: with ps; [
  pip
  setuptools
])
