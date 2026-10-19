#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=dotfiles-link-common.sh
source "${SCRIPT_DIR}/dotfiles-link-common.sh"

SOURCE_DIR="${HOME}/.config/nvim"
TARGET_DIR="${SCRIPT_DIR}/dotfiles/nvim"

usage() {
  cat <<'EOF'
Usage:
  ./sync-nvim-config.sh backup   # Export current machine Neovim config to repository
  ./sync-nvim-config.sh restore  # Link portable entries and preserve local runtime state
EOF
}

copy_nvim_entry() {
  local source_entry="$1"
  local staging_dir="$2"
  local name
  name="$(basename "${source_entry}")"
  local copy_source="${source_entry}"
  local canonical_target_dir
  canonical_target_dir="$(cd -P "${TARGET_DIR}" && pwd)"

  if [[ -L "${source_entry}" ]]; then
    local link_target
    link_target="$(readlink "${source_entry}")"
    if [[ "${link_target}" != /* ]]; then
      link_target="$(dirname "${source_entry}")/${link_target}"
    fi
    local link_parent
    link_parent="$(cd -P "$(dirname "${link_target}")" && pwd)"
    link_target="${link_parent}/$(basename "${link_target}")"

    case "${link_target}" in
      "${canonical_target_dir}/"*)
        copy_source="${link_target}"
        if [[ ! -e "${copy_source}" ]]; then
          local fallback="${source_entry}.bak.pre-dotfiles"
          if [[ -e "${fallback}" || -L "${fallback}" ]]; then
            copy_source="${fallback}"
          else
            echo "[nvim-sync] Managed source is unreadable and has no backup: ${source_entry}" >&2
            return 1
          fi
        fi
        ;;
      *)
        echo "[nvim-sync] Skip external symlink: ${source_entry} -> ${link_target}"
        return 0
        ;;
    esac
  fi

  if [[ -d "${copy_source}" ]]; then
    mkdir -p "${staging_dir}/${name}"
    rsync -a --safe-links "${copy_source}/" "${staging_dir}/${name}/"
  elif [[ -f "${copy_source}" ]]; then
    cp -pL "${copy_source}" "${staging_dir}/${name}"
  fi
}

backup_config() {
  local source_init_lua="${SOURCE_DIR}/init.lua"
  local source_init_vim="${SOURCE_DIR}/init.vim"

  if [[ ! -f "${source_init_lua}" && ! -L "${source_init_lua}" && ! -f "${source_init_vim}" && ! -L "${source_init_vim}" ]]; then
    echo "[nvim-sync] Source config not found in ${SOURCE_DIR}" >&2
    exit 1
  fi

  if [[ -L "${SOURCE_DIR}" ]]; then
    echo "[nvim-sync] ~/.config/nvim is symlinked to repo; edit ${TARGET_DIR} directly."
    return 0
  fi

  local staging_dir
  staging_dir="$(mktemp -d)"
  local source_entry
  while IFS= read -r -d '' source_entry; do
    local name
    name="$(basename "${source_entry}")"
    case "${name}" in
      .git | .claude | *.log | *.bak.pre-dotfiles | *.bak.pre-dotfiles-*) continue ;;
    esac
    if ! copy_nvim_entry "${source_entry}" "${staging_dir}"; then
      rm -rf "${staging_dir}"
      return 1
    fi
  done < <(find "${SOURCE_DIR}" -mindepth 1 -maxdepth 1 -print0)

  mkdir -p "${TARGET_DIR}"
  if ! rsync -a --delete "${staging_dir}/" "${TARGET_DIR}/"; then
    rm -rf "${staging_dir}"
    return 1
  fi
  rm -rf "${staging_dir}"
  echo "[nvim-sync] Exported Neovim config to ${TARGET_DIR}"
}

restore_config() {
  local target_init_lua="${TARGET_DIR}/init.lua"
  local target_init_vim="${TARGET_DIR}/init.vim"

  if [[ ! -f "${target_init_lua}" && ! -f "${target_init_vim}" ]]; then
    echo "[nvim-sync] Backup config not found in ${TARGET_DIR}" >&2
    exit 1
  fi

  mkdir -p "$(dirname "${SOURCE_DIR}")"
  if [[ -L "${SOURCE_DIR}" ]]; then
    local backup_path
    backup_path="$(next_dotfiles_backup_path "${SOURCE_DIR}")"
    mv "${SOURCE_DIR}" "${backup_path}"
  elif [[ -e "${SOURCE_DIR}" && ! -d "${SOURCE_DIR}" ]]; then
    local backup_path
    backup_path="$(next_dotfiles_backup_path "${SOURCE_DIR}")"
    mv "${SOURCE_DIR}" "${backup_path}"
  fi
  mkdir -p "${SOURCE_DIR}"

  local live_entry
  while IFS= read -r -d '' live_entry; do
    local link_target
    link_target="$(readlink "${live_entry}")"
    case "${link_target}" in
      "${TARGET_DIR}/"*)
        if [[ ! -e "${link_target}" && ! -L "${link_target}" ]]; then
          rm "${live_entry}"
        fi
        ;;
    esac
  done < <(find "${SOURCE_DIR}" -mindepth 1 -maxdepth 1 -type l -print0)

  local target_entry
  while IFS= read -r -d '' target_entry; do
    ensure_symlink "${SOURCE_DIR}/$(basename "${target_entry}")" "${target_entry}"
  done < <(find "${TARGET_DIR}" -mindepth 1 -maxdepth 1 ! -name '.claude' ! -name '.git' -print0)
  echo "[nvim-sync] Linked portable Neovim config entries from ${TARGET_DIR}"
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
