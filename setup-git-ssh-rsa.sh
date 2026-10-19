#!/usr/bin/env bash
set -euo pipefail

GIT_USER_NAME="${GIT_USER_NAME:-}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-}"
SSH_KEY_PATH="${SSH_KEY_PATH:-${HOME}/.ssh/id_rsa}"
SSH_KEY_BITS="${SSH_KEY_BITS:-4096}"
BACKUP_SUFFIX="$(date +%Y%m%d%H%M%S)"

usage() {
  cat <<'EOF'
Usage:
  GIT_USER_NAME="Your Name" GIT_USER_EMAIL="you@example.com" ./setup-git-ssh-rsa.sh

Set the global Git author identity, generate an RSA key pair, and print the
public key.

Optional environment overrides:
  SSH_KEY_PATH         default: ~/.ssh/id_rsa
  SSH_KEY_BITS         default: 4096
  SSH_KEY_PASSPHRASE   passphrase for the key; unset/empty = none (batch mode)

  ./setup-git-ssh-rsa.sh --help   Show this text
EOF
}

log() {
  printf '[setup-git-ssh-rsa] %s\n' "$*"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if ! command -v git >/dev/null 2>&1; then
  log "git not found in PATH."
  exit 1
fi

if ! command -v ssh-keygen >/dev/null 2>&1; then
  log "ssh-keygen not found in PATH."
  exit 1
fi

if [[ -z "${GIT_USER_NAME}" || -z "${GIT_USER_EMAIL}" ]]; then
  log "Set GIT_USER_NAME and GIT_USER_EMAIL before running this script."
  exit 1
fi

mkdir -p "${HOME}/.ssh"
chmod 700 "${HOME}/.ssh"

log "Setting global Git author identity"
git config --global user.name "${GIT_USER_NAME}"
git config --global user.email "${GIT_USER_EMAIL}"

if [[ -f "${SSH_KEY_PATH}" ]]; then
  backup="${SSH_KEY_PATH}.backup.${BACKUP_SUFFIX}"
  log "Backing up existing key to ${backup}"
  cp "${SSH_KEY_PATH}" "${backup}"
  if [[ -f "${SSH_KEY_PATH}.pub" ]]; then
    cp "${SSH_KEY_PATH}.pub" "${backup}.pub"
  fi
  rm -f "${SSH_KEY_PATH}" "${SSH_KEY_PATH}.pub"
fi

log "Generating RSA (${SSH_KEY_BITS} bits) -> ${SSH_KEY_PATH}"
ssh-keygen -t rsa -b "${SSH_KEY_BITS}" -C "${GIT_USER_EMAIL}" \
  -f "${SSH_KEY_PATH}" -N "${SSH_KEY_PASSPHRASE:-}" -q

chmod 600 "${SSH_KEY_PATH}"
chmod 644 "${SSH_KEY_PATH}.pub"

log "Public key:"
printf '\n'
sed -n '1p' "${SSH_KEY_PATH}.pub"
printf '\n'
