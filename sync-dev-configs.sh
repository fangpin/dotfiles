#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM="${DOTFILES_PLATFORM:-$(uname -s)}"
FAILED_STEPS=()

usage() {
  cat <<'EOF'
Usage:
  ./sync-dev-configs.sh backup   # Save portable development settings to this repository
  ./sync-dev-configs.sh restore  # Restore repository settings to this machine
  ./sync-dev-configs.sh status   # Compare AI application and macOS settings

SSH private keys are intentionally excluded. Use ./sync-ssh-key.sh explicitly.
EOF
}

run_step() {
  local label="$1"
  local script="$2"
  local action="$3"
  local path="${SCRIPT_DIR}/${script}"

  echo "[dev-sync] ${action}: ${label}"
  if [[ ! -f "${path}" ]]; then
    echo "[dev-sync] Missing ${path}" >&2
    FAILED_STEPS+=("${label}")
    return 0
  fi

  bash "${path}" "${action}"
  local status=$?
  if [[ "${status}" -ne 0 ]]; then
    echo "[dev-sync] ${label} failed with exit ${status}" >&2
    FAILED_STEPS+=("${label}")
  fi
}

run_backup_or_restore() {
  local action="$1"
  run_step zsh sync-zsh-config.sh "${action}"
  run_step git sync-gitconfig.sh "${action}"
  run_step nvim sync-nvim-config.sh "${action}"
  if [[ "${PLATFORM}" == "Darwin" ]]; then
    run_step karabiner sync-karabiner-config.sh "${action}"
  fi
  run_step cursor sync-cursor-config.sh "${action}"
  run_step lark-channel sync-lark-channel-config.sh "${action}"
  run_step agents sync-agents-config.sh "${action}"
  run_step go-src sync-go-src-repos.sh "${action}"
  run_step ai-apps sync-ai-app-configs.sh "${action}"
  if [[ "${PLATFORM}" == "Darwin" ]]; then
    run_step macos sync-macos-settings.sh "${action}"
  fi
}

run_status() {
  echo "[dev-sync] status checks portable AI application settings and macOS preferences."
  run_step ai-apps sync-ai-app-configs.sh status
  if [[ "${PLATFORM}" == "Darwin" ]]; then
    run_step macos sync-macos-settings.sh status
  fi
}

main() {
  if [[ $# -ne 1 ]]; then
    usage
    exit 1
  fi

  case "$1" in
    backup | restore) run_backup_or_restore "$1" ;;
    status) run_status ;;
    *) usage; exit 1 ;;
  esac

  if [[ "${#FAILED_STEPS[@]}" -gt 0 ]]; then
    echo "[dev-sync] Failed steps: ${FAILED_STEPS[*]}" >&2
    exit 1
  fi
  echo "[dev-sync] $1 complete."
}

main "$@"
