#!/usr/bin/env bash
set +e
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_SSH_DIR="${HOME}/.ssh"
SOURCE_SSH_KEY="${SOURCE_SSH_DIR}/id_ed25519"
SOURCE_SSH_PUB="${SOURCE_SSH_KEY}.pub"
PRIVATE_STORAGE_DIR="${DOTFILES_PRIVATE_DIR:-${HOME}/.local/share/dotfiles-private}/ssh"
TARGET_ENCRYPTED_KEY="${PRIVATE_STORAGE_DIR}/id_ed25519.enc"
TARGET_PUBLIC_KEY="${PRIVATE_STORAGE_DIR}/id_ed25519.pub"
BACKUP_SUFFIX="$(date +%Y%m%d%H%M%S)"

usage() {
  cat <<'EOF'
Usage:
  ./sync-ssh-key.sh backup   # Encrypt ~/.ssh/id_ed25519 into private storage outside the repo
  ./sync-ssh-key.sh restore  # Decrypt private storage back to ~/.ssh/id_ed25519

Optional environment variable:
  DOTFILES_PRIVATE_DIR=...          # Default: ~/.local/share/dotfiles-private
  SSH_KEY_ENCRYPTION_PASSWORD=...   # Skip interactive password input
EOF
}

log() {
  printf "[ssh-key-sync] %s\n" "$*"
}

backup_if_exists() {
  local target="$1"
  if [[ -e "${target}" || -L "${target}" ]]; then
    local backup="${target}.backup.${BACKUP_SUFFIX}"
    cp -R "${target}" "${backup}"
    log "Backed up ${target} -> ${backup}"
  fi
}

read_secret_once() {
  local prompt="$1"
  local secret="${SSH_KEY_ENCRYPTION_PASSWORD:-}"

  if [[ -n "${secret}" ]]; then
    printf "%s" "${secret}"
    return 0
  fi

  if [[ ! -t 0 ]]; then
    return 1
  fi

  read -r -s -p "${prompt}" secret
  printf "\n" >&2
  printf "%s" "${secret}"
}

read_secret_with_confirm() {
  local secret="${SSH_KEY_ENCRYPTION_PASSWORD:-}"
  if [[ -n "${secret}" ]]; then
    printf "%s" "${secret}"
    return 0
  fi

  if [[ ! -t 0 ]]; then
    return 1
  fi

  local first
  local second
  read -r -s -p "[ssh-key-sync] Enter encryption password: " first
  printf "\n" >&2
  read -r -s -p "[ssh-key-sync] Confirm encryption password: " second
  printf "\n" >&2

  if [[ "${first}" != "${second}" ]]; then
    log "Password mismatch."
    return 2
  fi

  printf "%s" "${first}"
}

backup_key() {
  if [[ ! -f "${SOURCE_SSH_KEY}" ]]; then
    log "Source SSH key not found: ${SOURCE_SSH_KEY}"
    exit 1
  fi

  local password
  if ! password="$(read_secret_with_confirm)"; then
    log "Password input unavailable. Set SSH_KEY_ENCRYPTION_PASSWORD or run interactively."
    exit 1
  fi

  if [[ -z "${password}" ]]; then
    log "Empty password is not allowed."
    exit 1
  fi

  mkdir -p "${PRIVATE_STORAGE_DIR}"
  chmod 700 "${PRIVATE_STORAGE_DIR}"

  if ! printf "%s" "${password}" | openssl enc -aes-256-cbc -pbkdf2 -iter 200000 -salt \
    -in "${SOURCE_SSH_KEY}" -out "${TARGET_ENCRYPTED_KEY}" -pass stdin >/dev/null 2>&1; then
    rm -f "${TARGET_ENCRYPTED_KEY}"
    log "Failed to encrypt SSH key."
    exit 1
  fi

  chmod 600 "${TARGET_ENCRYPTED_KEY}"

  if [[ -f "${SOURCE_SSH_PUB}" ]]; then
    cp "${SOURCE_SSH_PUB}" "${TARGET_PUBLIC_KEY}"
  else
    ssh-keygen -y -f "${SOURCE_SSH_KEY}" > "${TARGET_PUBLIC_KEY}"
  fi
  chmod 644 "${TARGET_PUBLIC_KEY}"
  log "Encrypted SSH key exported to ${TARGET_ENCRYPTED_KEY}"
}

restore_key() {
  if [[ ! -f "${TARGET_ENCRYPTED_KEY}" ]]; then
    log "Encrypted key not found: ${TARGET_ENCRYPTED_KEY}"
    exit 1
  fi

  local password
  if ! password="$(read_secret_once '[ssh-key-sync] Enter password to decrypt SSH key: ')"; then
    log "Password input unavailable. Set SSH_KEY_ENCRYPTION_PASSWORD or run interactively."
    exit 1
  fi

  if [[ -z "${password}" ]]; then
    log "Empty password is not allowed."
    exit 1
  fi

  mkdir -p "${SOURCE_SSH_DIR}"
  chmod 700 "${SOURCE_SSH_DIR}"
  backup_if_exists "${SOURCE_SSH_KEY}"
  backup_if_exists "${SOURCE_SSH_PUB}"

  if ! printf "%s" "${password}" | openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 -salt \
    -in "${TARGET_ENCRYPTED_KEY}" -out "${SOURCE_SSH_KEY}" -pass stdin >/dev/null 2>&1; then
    rm -f "${SOURCE_SSH_KEY}"
    log "Failed to decrypt SSH key. Check password."
    exit 1
  fi

  chmod 600 "${SOURCE_SSH_KEY}"

  if [[ -f "${TARGET_PUBLIC_KEY}" ]]; then
    cp "${TARGET_PUBLIC_KEY}" "${SOURCE_SSH_PUB}"
  else
    ssh-keygen -y -f "${SOURCE_SSH_KEY}" > "${SOURCE_SSH_PUB}"
  fi
  chmod 644 "${SOURCE_SSH_PUB}"
  log "SSH key restored to ${SOURCE_SSH_KEY}"
}

main() {
  if [[ $# -ne 1 ]]; then
    usage
    exit 1
  fi

  case "$1" in
    backup) backup_key ;;
    restore) restore_key ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
