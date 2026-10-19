#!/usr/bin/env bash
set -euo pipefail

# Install JetBrains DataGrip without running the full bootstrap.
# For repeatable installs, prefer `cask "datagrip"` in Brewfile + `brew bundle`.

if ! command -v brew >/dev/null 2>&1; then
  echo "[install-datagrip] Homebrew not found. Run ./bootstrap-mac.sh or install from https://brew.sh" >&2
  exit 1
fi

echo "[install-datagrip] Installing DataGrip..."
brew install --cask datagrip
echo "[install-datagrip] Done. Launch from Applications or run: datagrip"
