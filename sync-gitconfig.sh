#!/usr/bin/env bash
set +e
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=dotfiles-link-common.sh
source "${SCRIPT_DIR}/dotfiles-link-common.sh"

SOURCE_GITCONFIG="${HOME}/.gitconfig"
TARGET_GITCONFIG="${SCRIPT_DIR}/dotfiles/.gitconfig"

usage() {
  cat <<'EOF'
Usage:
  ./sync-gitconfig.sh backup   # Export an allowlisted, identity-free Git config
  ./sync-gitconfig.sh restore  # Link ~/.gitconfig -> dotfiles/.gitconfig
EOF
}

backup_config() {
  if [[ ! -f "${SOURCE_GITCONFIG}" ]]; then
    echo "[gitconfig-sync] Source not found: ${SOURCE_GITCONFIG}" >&2
    exit 1
  fi

  mkdir -p "$(dirname "${TARGET_GITCONFIG}")"
  local temporary
  temporary="$(mktemp)"

  local key
  local value
  for key in init.defaultBranch core.editor pull.ff fetch.prune rerere.enabled; do
    value="$(git config --global --get "${key}" || true)"
    if [[ -n "${value}" ]]; then
      git config --file "${temporary}" "${key}" "${value}"
    fi
  done

  mv "${temporary}" "${TARGET_GITCONFIG}"
  echo "[gitconfig-sync] Exported portable settings without identity, credentials, URL rewrites, or hooks."
}

restore_config() {
  if [[ ! -f "${TARGET_GITCONFIG}" ]]; then
    echo "[gitconfig-sync] Repo file not found: ${TARGET_GITCONFIG}" >&2
    exit 1
  fi

  ensure_symlink "${SOURCE_GITCONFIG}" "${TARGET_GITCONFIG}"
  echo "[gitconfig-sync] Linked ~/.gitconfig to repository."
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
