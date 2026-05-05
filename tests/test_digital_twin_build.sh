#!/usr/bin/env bash
# RED: assert Dockerfile.digital-twin exists and builds
set -euo pipefail

DOCKER_DIR="$(dirname "$0")/../docker"

if [[ ! -f "$DOCKER_DIR/Dockerfile.digital-twin" ]]; then
  echo "FAIL: docker/Dockerfile.digital-twin not found"
  exit 1
fi

# Assert required install stages present
for stage in apt nvm node claude "claude-plugins" hindsight qwen gemini; do
  if ! grep -qi "$stage" "$DOCKER_DIR/Dockerfile.digital-twin"; then
    echo "FAIL: Dockerfile.digital-twin missing stage: $stage"
    exit 1
  fi
done

# Assert base image is ubuntu 24.04
if ! grep -q "FROM ubuntu:24.04" "$DOCKER_DIR/Dockerfile.digital-twin"; then
  echo "FAIL: base image must be ubuntu:24.04"
  exit 1
fi

# Assert dotfiles seeded
if ! grep -q "dotfiles" "$DOCKER_DIR/Dockerfile.digital-twin"; then
  echo "FAIL: Dockerfile.digital-twin must seed ~/dotfiles"
  exit 1
fi

# Build test (skipped in CI without docker; set SKIP_DOCKER_BUILD=1 to skip)
if [[ "${SKIP_DOCKER_BUILD:-0}" != "1" ]]; then
  if ! command -v docker &>/dev/null; then
    echo "SKIP: docker not available"
    exit 0
  fi
  docker build -f "$DOCKER_DIR/Dockerfile.digital-twin" "$DOCKER_DIR" \
    --target base --quiet > /dev/null \
    && echo "PASS: Dockerfile.digital-twin builds (base stage)" \
    || { echo "FAIL: docker build failed"; exit 1; }
else
  echo "PASS: Dockerfile.digital-twin structure valid (build skipped)"
fi
