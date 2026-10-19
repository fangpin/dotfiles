#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DEBIAN="${SCRIPT_DIR}/bootstrap-debian.sh"

usage() {
  cat <<'EOF'
Bootstrap a Debian 12 (bookworm) machine with the same dotfiles flow as
bootstrap-mac.sh where possible.

Usage:
  ./bootstrap-debian12.sh [--force]

Options:
  --force  Run even when /etc/os-release is not Debian 12/bookworm.

Do not run this script with sudo. It manages dotfiles for the current user and
will ask for sudo only for apt/chsh steps that need it.
EOF
}

force=0
args=()
for arg in "$@"; do
  case "${arg}" in
    -h|--help)
      usage
      exit 0
      ;;
    --force)
      force=1
      ;;
    *)
      args+=("${arg}")
      ;;
  esac
done

if [[ "${EUID}" -eq 0 && -n "${SUDO_USER:-}" ]]; then
  echo "[bootstrap-debian12] Do not run this script with sudo." >&2
  echo "[bootstrap-debian12] Run ./bootstrap-debian12.sh and let individual steps ask for sudo." >&2
  exit 1
fi

if [[ ! -f /etc/os-release ]]; then
  echo "[bootstrap-debian12] /etc/os-release not found." >&2
  if [[ "${force}" -ne 1 ]]; then
    echo "[bootstrap-debian12] Use --force to run anyway." >&2
    exit 1
  fi
else
  # shellcheck source=/dev/null
  source /etc/os-release
  os_id="${ID:-}"
  version_id="${VERSION_ID:-}"
  version_codename="${VERSION_CODENAME:-}"

  if [[ "${force}" -ne 1 ]]; then
    if [[ "${os_id}" != "debian" || ( "${version_id}" != "12" && "${version_codename}" != "bookworm" ) ]]; then
      echo "[bootstrap-debian12] Expected Debian 12/bookworm, got ID=${os_id:-unknown} VERSION_ID=${version_id:-unknown} VERSION_CODENAME=${version_codename:-unknown}." >&2
      echo "[bootstrap-debian12] Use --force to run anyway, or use ./bootstrap-debian.sh for generic Debian/Ubuntu." >&2
      exit 1
    fi
  fi
fi

if [[ ! -x "${BOOTSTRAP_DEBIAN}" ]]; then
  echo "[bootstrap-debian12] Missing executable ${BOOTSTRAP_DEBIAN}." >&2
  exit 1
fi

echo "[bootstrap-debian12] Debian 12/bookworm check passed; running bootstrap-debian.sh..."
exec "${BOOTSTRAP_DEBIAN}" "${args[@]}"
