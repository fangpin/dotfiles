#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETTINGS_TOOL="${SCRIPT_DIR}/scripts/macos-settings.mjs"
SNAPSHOT="${SCRIPT_DIR}/dotfiles/macos/settings.json"
LOCAL_BACKUP_DIR="${HOME}/Library/Application Support/bytedotfiles/backups"

usage() {
  cat <<'EOF'
Usage:
  ./sync-macos-settings.sh backup   # Save allowlisted macOS settings
  ./sync-macos-settings.sh restore  # Restore settings and keep a local rollback snapshot
  ./sync-macos-settings.sh status   # Report allowlisted settings that differ

Touch ID, Apple ID, Wi-Fi credentials, privacy permissions, and display arrangement
are intentionally not managed.
EOF
}

require_macos_tools() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "[macos-sync] macOS is required; skipping." >&2
    return 1
  fi
  if ! command -v node >/dev/null 2>&1; then
    echo "[macos-sync] node is required." >&2
    return 1
  fi
  [[ -f "${SETTINGS_TOOL}" ]] || {
    echo "[macos-sync] Missing settings tool: ${SETTINGS_TOOL}" >&2
    return 1
  }
}

backup_settings() {
  require_macos_tools
  node "${SETTINGS_TOOL}" backup "${SNAPSHOT}" "${HOME}"
  echo "[macos-sync] Saved allowlisted settings to ${SNAPSHOT}"
}

restore_settings() {
  require_macos_tools
  if [[ ! -f "${SNAPSHOT}" ]]; then
    echo "[macos-sync] Snapshot not found: ${SNAPSHOT}" >&2
    exit 1
  fi

  if node "${SETTINGS_TOOL}" status "${SNAPSHOT}" "${HOME}" >/dev/null 2>&1; then
    echo "[macos-sync] Settings are already synchronized; no restore needed."
    return 0
  fi

  mkdir -p "${LOCAL_BACKUP_DIR}"
  local rollback_snapshot
  rollback_snapshot="${LOCAL_BACKUP_DIR}/macos-settings-$(date '+%Y%m%d-%H%M%S').json"
  node "${SETTINGS_TOOL}" backup "${rollback_snapshot}" "${HOME}"
  node "${SETTINGS_TOOL}" restore "${SNAPSHOT}" "${HOME}"

  if [[ "${DOTFILES_SKIP_RESTART:-0}" != "1" ]]; then
    killall cfprefsd >/dev/null 2>&1 || true
    killall Dock >/dev/null 2>&1 || true
    killall Finder >/dev/null 2>&1 || true
    killall SystemUIServer >/dev/null 2>&1 || true
  fi
  echo "[macos-sync] Restored settings. Rollback snapshot: ${rollback_snapshot}"
  echo "[macos-sync] Input sources and some gestures may require signing out and back in."
}

status_settings() {
  require_macos_tools
  if [[ ! -f "${SNAPSHOT}" ]]; then
    echo "[macos-sync] Snapshot not found: ${SNAPSHOT}" >&2
    exit 1
  fi
  node "${SETTINGS_TOOL}" status "${SNAPSHOT}" "${HOME}"
}

main() {
  if [[ $# -ne 1 ]]; then
    usage
    exit 1
  fi
  case "$1" in
    backup) backup_settings ;;
    restore) restore_settings ;;
    status) status_settings ;;
    *) usage; exit 1 ;;
  esac
}

main "$@"
