#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=dotfiles-link-common.sh
source "${SCRIPT_DIR}/dotfiles-link-common.sh"

TARGET_DIR="${SCRIPT_DIR}/dotfiles"
SOURCE_ZSHRC="${HOME}/.zshrc"
SOURCE_ZPROFILE="${HOME}/.zprofile"
TARGET_ZSHRC="${TARGET_DIR}/.zshrc"
TARGET_ZPROFILE="${TARGET_DIR}/.zprofile"
SANITIZER="${SCRIPT_DIR}/scripts/config-sanitizer.mjs"

usage() {
  cat <<'EOF'
Usage:
  ./sync-zsh-config.sh backup   # Export and sanitize current zsh config
  ./sync-zsh-config.sh restore  # Render repository config while preserving local secrets
EOF
}

run_sanitizer() {
  local node_bin
  node_bin="$(command -v node || true)"
  if [[ -z "${node_bin}" ]]; then
    echo "[zsh-sync] Node.js is required for secret-safe zsh sync." >&2
    return 1
  fi
  "${node_bin}" "${SANITIZER}" "$@"
}

backup_config() {
  if [[ ! -f "${SOURCE_ZSHRC}" || ! -f "${SOURCE_ZPROFILE}" ]]; then
    echo "[zsh-sync] Source config not found: ~/.zshrc or ~/.zprofile" >&2
    exit 1
  fi

  mkdir -p "${TARGET_DIR}"

  run_sanitizer shell-backup "${SOURCE_ZSHRC}" "${TARGET_ZSHRC}" "${HOME}"
  run_sanitizer shell-backup "${SOURCE_ZPROFILE}" "${TARGET_ZPROFILE}" "${HOME}"
  echo "[zsh-sync] Exported sanitized zsh config to ${TARGET_DIR}"
}

canonical_file_path() {
  local path="$1"
  local parent
  parent="$(cd -P "$(dirname "${path}")" && pwd)"
  printf '%s/%s\n' "${parent}" "$(basename "${path}")"
}

resolved_source_path() {
  local path="$1"
  if [[ ! -L "${path}" ]]; then
    canonical_file_path "${path}"
    return
  fi

  local link_target
  link_target="$(readlink "${path}")"
  if [[ "${link_target}" != /* ]]; then
    link_target="$(dirname "${path}")/${link_target}"
  fi
  canonical_file_path "${link_target}"
}

copy_if_not_managed() {
  local source="$1"
  local target="$2"
  local source_path
  local target_path
  source_path="$(resolved_source_path "${source}")"
  target_path="$(canonical_file_path "${target}")"

  if [[ "${source_path}" == "${target_path}" ]]; then
    echo "[zsh-sync] Already managed by this repository: ${source}"
    return 0
  fi

  cp -L "${source}" "${target}"
}

restore_config() {
  if [[ ! -f "${TARGET_ZSHRC}" || ! -f "${TARGET_ZPROFILE}" ]]; then
    echo "[zsh-sync] Backup config not found in ${TARGET_DIR}" >&2
    exit 1
  fi

  backup_live_file_once "${SOURCE_ZSHRC}"
  backup_live_file_once "${SOURCE_ZPROFILE}"
  run_sanitizer shell-restore "${TARGET_ZSHRC}" "${SOURCE_ZSHRC}" "${SOURCE_ZSHRC}" "${HOME}"
  run_sanitizer shell-restore "${TARGET_ZPROFILE}" "${SOURCE_ZPROFILE}" "${SOURCE_ZPROFILE}" "${HOME}"
  echo "[zsh-sync] Rendered zsh config from ${TARGET_DIR}"
}

backup_live_file_once() {
  local live="$1"
  local backup="${live}.bak.pre-dotfiles"
  if [[ (-e "${live}" || -L "${live}") && ! -e "${backup}" && ! -L "${backup}" ]]; then
    cp -L "${live}" "${backup}"
  fi
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
