#!/usr/bin/env bash
set +e
set -u

preferred_zsh_path() {
  if [[ -x /opt/homebrew/bin/zsh ]]; then
    printf '%s\n' /opt/homebrew/bin/zsh
    return
  fi
  if [[ -x /usr/local/bin/zsh ]]; then
    printf '%s\n' /usr/local/bin/zsh
    return
  fi
  printf '%s\n' /bin/zsh
}

current_login_shell() {
  dscl . -read "/Users/$(id -un)" UserShell 2>/dev/null | awk 'NF > 1 { print $2 }'
}

shell_in_etc_shells() {
  grep -qxF "$1" /etc/shells 2>/dev/null
}

ensure_etc_shells() {
  local p="$1"
  if shell_in_etc_shells "${p}"; then
    return 0
  fi
  echo "[set-shell] Adding ${p} to /etc/shells (sudo)…"
  if ! echo "${p}" | sudo tee -a /etc/shells >/dev/null; then
    return 1
  fi
  return 0
}

usage() {
  cat <<'EOF'
Set your macOS login shell to zsh. Prefers Homebrew zsh when installed; otherwise
uses /bin/zsh. You may be prompted for sudo (to update /etc/shells) and your user
password (for chsh).

Usage:
  ./set-default-shell-zsh.sh
EOF
}

main() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi

  local want current
  want="$(preferred_zsh_path)"
  current="$(current_login_shell)"

  if [[ -z "${want}" ]]; then
    echo "[set-shell] Could not resolve a zsh binary." >&2
    exit 1
  fi

  if [[ "${current}" == "${want}" ]]; then
    echo "[set-shell] Login shell is already ${want}."
    exit 0
  fi

  echo "[set-shell] Current login shell: ${current:-unknown}"
  echo "[set-shell] Target: ${want}"

  if ! ensure_etc_shells "${want}"; then
    echo "[set-shell] Failed to ensure ${want} is listed in /etc/shells." >&2
    exit 1
  fi

  if ! chsh -s "${want}"; then
    echo "[set-shell] chsh failed. Try manually: chsh -s ${want}" >&2
    exit 1
  fi

  echo "[set-shell] Login shell set to ${want}. Open a new terminal tab or log out and back in."
}

main "$@"
