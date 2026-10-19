#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=dotfiles-link-common.sh
source "${SCRIPT_DIR}/dotfiles-link-common.sh"

SANITIZER="${SCRIPT_DIR}/scripts/config-sanitizer.mjs"
CODEX_TARGET="${SCRIPT_DIR}/dotfiles/codex"
TRAEX_TARGET="${SCRIPT_DIR}/dotfiles/traex"
CLAUDE_TARGET="${SCRIPT_DIR}/dotfiles/claude"
GHOSTTY_TARGET="${SCRIPT_DIR}/dotfiles/ghostty"

usage() {
  cat <<'EOF'
Usage:
  ./sync-ai-app-configs.sh backup   # Refuse automatic export; templates require review
  ./sync-ai-app-configs.sh restore  # Restore settings while preserving local credentials
  ./sync-ai-app-configs.sh status   # Compare portable live settings with the repository

Managed applications: Codex, TraeX, Claude, and Ghostty.
Repository templates are restored automatically but must be curated manually before
publishing. Raw application configs can contain project history and internal endpoints.
EOF
}

require_node() {
  if ! command -v node >/dev/null 2>&1; then
    echo "[ai-app-sync] node is required." >&2
    exit 1
  fi
  if [[ ! -f "${SANITIZER}" ]]; then
    echo "[ai-app-sync] Missing sanitizer: ${SANITIZER}" >&2
    exit 1
  fi
}

copy_optional_file() {
  local source="$1"
  local target="$2"
  if [[ ! -f "${source}" ]]; then
    rm -f "${target}"
    return 0
  fi
  if [[ -e "${target}" && "${source}" -ef "${target}" ]]; then
    return 0
  fi
  mkdir -p "$(dirname "${target}")"
  cp -L "${source}" "${target}"
}

copy_optional_dir() {
  local source="$1"
  local target="$2"
  if [[ ! -d "${source}" ]]; then
    rm -rf "${target}"
    return 0
  fi
  mkdir -p "${target}"
  rsync -a --delete --exclude '.DS_Store' "${source}/" "${target}/"
}

backup_text_dir() {
  local source="$1"
  local target="$2"
  copy_optional_dir "${source}" "${target}"
  [[ -d "${target}" ]] || return 0

  local file
  while IFS= read -r -d '' file; do
    node "${SANITIZER}" text-backup "${file}" "${file}" "${HOME}"
  done < <(find "${target}" -type f -print0)
}

backup_toml() {
  local source="$1"
  local target="$2"
  if [[ -f "${source}" ]]; then
    node "${SANITIZER}" toml-backup "${source}" "${target}" "${HOME}"
  else
    rm -f "${target}"
  fi
}

backup_json() {
  local source="$1"
  local target="$2"
  if [[ -f "${source}" ]]; then
    node "${SANITIZER}" json-backup "${source}" "${target}" "${HOME}"
  else
    rm -f "${target}"
  fi
}

backup_claude_desktop() {
  local name="$1"
  local source="${HOME}/Library/Application Support/${name}/claude_desktop_config.json"
  local target="${CLAUDE_TARGET}/desktop-${name}.json"
  if [[ -f "${source}" ]]; then
    node "${SANITIZER}" claude-desktop-backup "${source}" "${target}" "${HOME}"
  else
    rm -f "${target}"
  fi
}

backup_config() {
  echo "[ai-app-sync] Automatic backup is disabled for a public repository."
  echo "[ai-app-sync] Edit the repository templates manually and review them before publishing."
}

backup_live_file_once() {
  local live="$1"
  local backup="${live}.bak.pre-dotfiles"
  if [[ -e "${live}" || -L "${live}" ]]; then
    if [[ ! -e "${backup}" && ! -L "${backup}" ]]; then
      cp -pL "${live}" "${backup}"
      echo "[ai-app-sync] Preserved original config: ${backup}"
    fi
  fi
}

backup_live_dir_once() {
  local live="$1"
  local backup="${live}.bak.pre-dotfiles"
  if [[ (-e "${live}" || -L "${live}") && ! -e "${backup}" && ! -L "${backup}" ]]; then
    cp -pRL "${live}" "${backup}"
    echo "[ai-app-sync] Preserved original config: ${backup}"
  fi
}

restore_text_dir() {
  local template_dir="$1"
  local live_dir="$2"
  [[ -d "${template_dir}" ]] || return 0

  backup_live_dir_once "${live_dir}"
  rm -rf "${live_dir}"
  mkdir -p "${live_dir}"
  local template
  while IFS= read -r -d '' template; do
    local relative="${template#${template_dir}/}"
    node "${SANITIZER}" text-restore "${template}" "${live_dir}/${relative}" "${HOME}"
  done < <(find "${template_dir}" -type f -print0)
}

restore_toml() {
  local template="$1"
  local live="$2"
  [[ -f "${template}" ]] || return 0
  mkdir -p "$(dirname "${live}")"
  backup_live_file_once "${live}"
  node "${SANITIZER}" toml-restore "${template}" "${live}" "${live}" "${HOME}"
}

restore_json() {
  local template="$1"
  local live="$2"
  [[ -f "${template}" ]] || return 0
  mkdir -p "$(dirname "${live}")"
  backup_live_file_once "${live}"
  node "${SANITIZER}" json-restore "${template}" "${live}" "${live}" "${HOME}"
}

restore_claude_desktop() {
  local name="$1"
  local template="${CLAUDE_TARGET}/desktop-${name}.json"
  local live="${HOME}/Library/Application Support/${name}/claude_desktop_config.json"
  [[ -f "${template}" ]] || return 0
  mkdir -p "$(dirname "${live}")"
  backup_live_file_once "${live}"
  node "${SANITIZER}" claude-desktop-restore "${template}" "${live}" "${live}" "${HOME}"
}

link_if_present() {
  local live="$1"
  local target="$2"
  [[ -e "${target}" || -L "${target}" ]] || return 0
  ensure_symlink "${live}" "${target}"
}

restore_config() {
  require_node

  restore_toml "${CODEX_TARGET}/config.toml" "${HOME}/.codex/config.toml"
  restore_json "${CODEX_TARGET}/hooks.json" "${HOME}/.codex/hooks.json"
  restore_toml "${CODEX_TARGET}/browser-config.toml" "${HOME}/.codex/browser/config.toml"
  link_if_present "${HOME}/.codex/AGENTS.md" "${CODEX_TARGET}/AGENTS.md"
  restore_text_dir "${CODEX_TARGET}/rules" "${HOME}/.codex/rules"

  restore_toml "${TRAEX_TARGET}/traecli.toml" "${HOME}/.trae/traecli.toml"
  restore_toml "${TRAEX_TARGET}/cli-config.toml" "${HOME}/.trae/cli/config.toml"

  restore_json "${CLAUDE_TARGET}/settings.json" "${HOME}/.claude/settings.json"
  link_if_present "${HOME}/.claude/AGENTS.md" "${CLAUDE_TARGET}/AGENTS.md"
  link_if_present "${HOME}/.claude/CLAUDE.md" "${CLAUDE_TARGET}/CLAUDE.md"
  restore_claude_desktop "Claude"
  restore_claude_desktop "Claude-3p"

  link_if_present "${HOME}/.config/ghostty/config" "${GHOSTTY_TARGET}/config"
  echo "[ai-app-sync] Portable application settings restored; local credentials were preserved."
}

STATUS_DRIFT=0

report_status() {
  local label="$1"
  local current="$2"
  local expected="$3"
  if [[ ! -e "${expected}" ]]; then
    echo "[missing snapshot] ${label}"
    STATUS_DRIFT=1
  elif cmp -s "${current}" "${expected}"; then
    echo "[synced] ${label}"
  else
    echo "[drift] ${label}"
    STATUS_DRIFT=1
  fi
}

status_config() {
  require_node
  local temporary
  temporary="$(mktemp -d)"
  local cleanup_command
  printf -v cleanup_command 'rm -rf -- %q' "${temporary}"
  trap "${cleanup_command}" EXIT

  if [[ -f "${HOME}/.codex/config.toml" ]]; then
    node "${SANITIZER}" toml-backup "${HOME}/.codex/config.toml" "${temporary}/codex.toml" "${HOME}"
    report_status "Codex config" "${temporary}/codex.toml" "${CODEX_TARGET}/config.toml"
  fi
  if [[ -f "${HOME}/.trae/traecli.toml" ]]; then
    node "${SANITIZER}" toml-backup "${HOME}/.trae/traecli.toml" "${temporary}/traex.toml" "${HOME}"
    report_status "TraeX config" "${temporary}/traex.toml" "${TRAEX_TARGET}/traecli.toml"
  fi
  if [[ -f "${HOME}/.claude/settings.json" ]]; then
    node "${SANITIZER}" json-backup "${HOME}/.claude/settings.json" "${temporary}/claude.json" "${HOME}"
    report_status "Claude settings" "${temporary}/claude.json" "${CLAUDE_TARGET}/settings.json"
  fi
  if [[ -f "${HOME}/.config/ghostty/config" ]]; then
    report_status "Ghostty config" "${HOME}/.config/ghostty/config" "${GHOSTTY_TARGET}/config"
  fi
  return "${STATUS_DRIFT}"
}

main() {
  if [[ $# -ne 1 ]]; then
    usage
    exit 1
  fi
  case "$1" in
    backup) backup_config ;;
    restore) restore_config ;;
    status) status_config ;;
    *) usage; exit 1 ;;
  esac
}

main "$@"
