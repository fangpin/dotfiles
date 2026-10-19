#!/usr/bin/env bash
set +e
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=dotfiles-link-common.sh
source "${SCRIPT_DIR}/dotfiles-link-common.sh"

SOURCE_DIR="${HOME}/.config/karabiner"
SOURCE_JSON="${SOURCE_DIR}/karabiner.json"
SOURCE_COMPLEX_DIR="${SOURCE_DIR}/assets/complex_modifications"

TARGET_DIR="${SCRIPT_DIR}/dotfiles/karabiner"
TARGET_JSON="${TARGET_DIR}/karabiner.json"
TARGET_COMPLEX_DIR="${TARGET_DIR}/assets/complex_modifications"

usage() {
  cat <<'EOF'
Usage:
  ./sync-karabiner-config.sh backup   # Export current machine Karabiner config to repository
  ./sync-karabiner-config.sh restore  # Symlink ~/.config/karabiner -> dotfiles/karabiner
EOF
}

backup_config() {
  if [[ ! -f "${SOURCE_JSON}" ]]; then
    echo "[karabiner-sync] Source config not found: ${SOURCE_JSON}" >&2
    exit 1
  fi

  if [[ -L "${SOURCE_DIR}" ]]; then
    echo "[karabiner-sync] ~/.config/karabiner is symlinked to repo; edit ${TARGET_DIR} directly."
    return 0
  fi

  mkdir -p "${TARGET_DIR}"
  cp "${SOURCE_JSON}" "${TARGET_JSON}"

  if [[ -d "${SOURCE_COMPLEX_DIR}" ]]; then
    mkdir -p "${TARGET_COMPLEX_DIR}"
    cp -R "${SOURCE_COMPLEX_DIR}/." "${TARGET_COMPLEX_DIR}/"
  fi

  echo "[karabiner-sync] Exported Karabiner config to ${TARGET_DIR}"
}

restore_config() {
  if [[ ! -f "${TARGET_JSON}" ]]; then
    echo "[karabiner-sync] Backup config not found: ${TARGET_JSON}" >&2
    exit 1
  fi

  mkdir -p "${HOME}/.config"
  ensure_symlink "${SOURCE_DIR}" "${TARGET_DIR}"
  echo "[karabiner-sync] Linked Karabiner config from ${TARGET_DIR}"
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
