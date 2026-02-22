#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

case "${1:-sync}" in
  pull)
    echo "Pulling latest dotfiles..."
    git pull --rebase || true
    ;;
  push)
    echo "Pushing dotfiles..."
    git add -A
    git diff --cached --quiet && echo "Nothing to commit." && exit 0
    git commit -m "auto: sync dotfiles $(date +%Y-%m-%d)"
    git push
    ;;
  sync)
    $0 pull
    $0 push
    ;;
  *)
    echo "Usage: $0 {pull|push|sync}"
    exit 1
    ;;
esac
