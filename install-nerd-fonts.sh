#!/usr/bin/env bash
set +e
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FONT_BREWFILE="${SCRIPT_DIR}/Brewfile.nerd-fonts"

activate_homebrew() {
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    return
  fi

  if [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
    return
  fi

  echo "[nerd-fonts] Homebrew not found. Install from https://brew.sh then retry." >&2
  exit 1
}

usage() {
  cat <<'EOF'
Install Nerd Fonts via Homebrew (see Brewfile.nerd-fonts for the list).

Usage:
  ./install-nerd-fonts.sh
EOF
}

main() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    return 0
  fi

  if [[ ! -f "${FONT_BREWFILE}" ]]; then
    echo "[nerd-fonts] Missing ${FONT_BREWFILE}" >&2
    exit 1
  fi

  activate_homebrew
  echo "[nerd-fonts] Installing casks from ${FONT_BREWFILE}..."
  brew bundle --file="${FONT_BREWFILE}"
  local st=$?
  if [[ "${st}" -eq 0 ]]; then
    echo "[nerd-fonts] Done. Select a Nerd Font in your terminal or editor settings."
  else
    echo "[nerd-fonts] brew bundle failed (exit ${st})." >&2
  fi
  exit "${st}"
}

main "$@"
