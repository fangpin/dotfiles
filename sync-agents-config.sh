#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=dotfiles-link-common.sh
source "${SCRIPT_DIR}/dotfiles-link-common.sh"

SOURCE_DIR="${HOME}/.agents"
TARGET_DIR="${SCRIPT_DIR}/dotfiles/.agents"

usage() {
  cat <<'EOF'
Usage:
  ./sync-agents-config.sh backup   # Export only top-level instruction files
  ./sync-agents-config.sh restore  # Restore only top-level instruction files

Skills, authentication, lock files, mount config, and runtime state stay local.
Review instruction files before publishing because they may contain project names.
EOF
}

copy_optional_file() {
  local source="$1"
  local target="$2"
  if [[ -f "${source}" ]]; then
    if [[ -e "${target}" && "${source}" -ef "${target}" ]]; then
      return 0
    fi
    mkdir -p "$(dirname "${target}")"
    cp "${source}" "${target}"
  fi
}

backup_config() {
  if [[ ! -d "${SOURCE_DIR}" ]]; then
    echo "[agents-sync] Source directory not found: ${SOURCE_DIR}" >&2
    exit 1
  fi

  mkdir -p "${TARGET_DIR}"
  copy_optional_file "${SOURCE_DIR}/agents.md" "${TARGET_DIR}/agents.md"
  copy_optional_file "${SOURCE_DIR}/AGENTS.md" "${TARGET_DIR}/AGENTS.md"
  echo "[agents-sync] Exported top-level instruction files; skills remain local."
}

restore_config() {
  mkdir -p "${SOURCE_DIR}" "${TARGET_DIR}"

  if [[ -f "${TARGET_DIR}/agents.md" ]]; then
    ensure_symlink "${SOURCE_DIR}/agents.md" "${TARGET_DIR}/agents.md"
  fi
  if [[ -f "${TARGET_DIR}/AGENTS.md" ]]; then
    if [[ ! -f "${TARGET_DIR}/agents.md" || ! "${TARGET_DIR}/agents.md" -ef "${TARGET_DIR}/AGENTS.md" ]]; then
      ensure_symlink "${SOURCE_DIR}/AGENTS.md" "${TARGET_DIR}/AGENTS.md"
    fi
  fi

  echo "[agents-sync] Linked top-level instruction files from ${TARGET_DIR}."
}

main() {
  if [[ $# -ne 1 ]]; then
    usage
    exit 1
  fi

  case "$1" in
    backup) backup_config ;;
    restore) restore_config ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
