#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[skills-sync] sync-skills.sh has been replaced by sync-cursor-config.sh."
exec "${SCRIPT_DIR}/sync-cursor-config.sh" "$@"
