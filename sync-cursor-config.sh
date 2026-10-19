#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=dotfiles-link-common.sh
source "${SCRIPT_DIR}/dotfiles-link-common.sh"

SOURCE_DIR="${HOME}/.cursor"
TARGET_DIR="${SCRIPT_DIR}/dotfiles/.cursor"
PORTABLE_FILES=(AGENTS.md argv.json blocklist)

usage() {
  cat <<'EOF'
Usage:
  ./sync-cursor-config.sh backup   # Export a small allowlist of portable files
  ./sync-cursor-config.sh restore  # Restore the same allowlisted files

Chats, projects, hooks, MCP config, rules, commands, skills, plugins, and machine
state stay local. Review the allowlisted files before publishing.
EOF
}

copy_optional_file() {
  local source="$1"
  local target="$2"
  [[ -f "${source}" ]] || return 0
  if [[ -e "${target}" && "${source}" -ef "${target}" ]]; then
    return 0
  fi
  mkdir -p "$(dirname "${target}")"
  cp -pL "${source}" "${target}"
}

backup_config() {
  if [[ ! -d "${SOURCE_DIR}" ]]; then
    echo "[cursor-sync] Source directory not found: ${SOURCE_DIR}" >&2
    exit 1
  fi

  mkdir -p "${TARGET_DIR}"
  local name
  for name in "${PORTABLE_FILES[@]}"; do
    copy_optional_file "${SOURCE_DIR}/${name}" "${TARGET_DIR}/${name}"
  done
  echo "[cursor-sync] Exported allowlisted files; private and project-specific data remain local."
}

restore_config() {
  mkdir -p "${SOURCE_DIR}"
  local name
  for name in "${PORTABLE_FILES[@]}"; do
    if [[ -e "${TARGET_DIR}/${name}" || -L "${TARGET_DIR}/${name}" ]]; then
      ensure_symlink "${SOURCE_DIR}/${name}" "${TARGET_DIR}/${name}"
    fi
  done
  echo "[cursor-sync] Linked allowlisted files from ${TARGET_DIR}."
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
