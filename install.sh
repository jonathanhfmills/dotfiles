#!/usr/bin/env bash
set -euo pipefail

REPO="https://github.com/jonathanhfmills/dotfiles.git"
DEST="${DOTFILES_DIR:-$HOME/dotfiles}"

if ! command -v git &>/dev/null; then
  sudo apt-get update -qq && sudo apt-get install -y git
fi

if [ -d "$DEST/.git" ]; then
  echo "dotfiles already present at $DEST — pulling latest"
  git -C "$DEST" pull --ff-only
else
  git clone "$REPO" "$DEST"
fi

make -C "$DEST" install
