#!/usr/bin/env bash
# Shared helpers for symlink-based dotfiles. Source from repo scripts:
#   source "${SCRIPT_DIR}/dotfiles-link-common.sh"

# Return a recoverable backup path without overwriting an older backup.
next_dotfiles_backup_path() {
  local path="$1"
  local base="${path}.bak.pre-dotfiles"

  if [[ ! -e "${base}" && ! -L "${base}" ]]; then
    printf '%s\n' "${base}"
    return 0
  fi

  local timestamp
  timestamp="$(date '+%Y%m%d-%H%M%S')"
  local candidate="${base}-${timestamp}"
  local counter=1
  while [[ -e "${candidate}" || -L "${candidate}" ]]; do
    candidate="${base}-${timestamp}-${counter}"
    counter=$((counter + 1))
  done
  printf '%s\n' "${candidate}"
}

# Create $link_path as a symlink to $target_path (absolute path used for the link target).
# If $link_path exists as the wrong symlink or a plain file/dir, move it to a recoverable
# *.bak.pre-dotfiles path first.
ensure_symlink() {
  local link_path="$1"
  local target_path="$2"

  if [[ ! -e "$target_path" ]]; then
    echo "[dotfiles-link] Skip — missing target: $target_path" >&2
    return 1
  fi

  local abs_target
  abs_target="$(cd "$(dirname "$target_path")" && pwd)/$(basename "$target_path")"

  mkdir -p "$(dirname "$link_path")"

  if [[ -L "$link_path" ]]; then
    if [[ "$(readlink "$link_path")" == "$abs_target" ]]; then
      echo "[dotfiles-link] OK (already linked): $link_path"
      return 0
    fi
  fi

  if [[ -e "$link_path" || -L "$link_path" ]]; then
    local backup_path
    backup_path="$(next_dotfiles_backup_path "$link_path")"
    echo "[dotfiles-link] Existing path at $link_path — moving to ${backup_path}"
    mv "$link_path" "$backup_path"
  fi

  ln -s "$abs_target" "$link_path"
  echo "[dotfiles-link] Linked $link_path -> $abs_target"
}
