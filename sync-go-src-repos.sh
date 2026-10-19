#!/usr/bin/env bash
set +e
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ROOT="${HOME}/go_repos/src"
MANIFEST_PATH="${SCRIPT_DIR}/dotfiles/go/src_repos_manifest.tsv"
ALLOWLIST_PATH="${PUBLIC_GO_REPOS_ALLOWLIST:-${HOME}/.config/dotfiles/public-go-remotes.txt}"

usage() {
  cat <<'EOF'
Usage:
  ./sync-go-src-repos.sh backup   # Export only remotes listed in the local public allowlist
  ./sync-go-src-repos.sh restore  # Clone repositories from manifest into ~/go_repos/src
EOF
}

backup_repos() {
  if [[ ! -d "${SOURCE_ROOT}" ]]; then
    echo "[go-src-sync] Source root not found: ${SOURCE_ROOT}" >&2
    exit 1
  fi

  if [[ ! -f "${ALLOWLIST_PATH}" ]]; then
    echo "[go-src-sync] Public remote allowlist not found: ${ALLOWLIST_PATH}" >&2
    echo "[go-src-sync] Add one exact public remote URL per line before exporting." >&2
    exit 1
  fi

  mkdir -p "$(dirname "${MANIFEST_PATH}")"

  SOURCE_ROOT="${SOURCE_ROOT}" MANIFEST_PATH="${MANIFEST_PATH}" ALLOWLIST_PATH="${ALLOWLIST_PATH}" python3 - <<'PY'
import os
import subprocess

source_root = os.environ["SOURCE_ROOT"]
manifest_path = os.environ["MANIFEST_PATH"]
allowlist_path = os.environ["ALLOWLIST_PATH"]
repos = []

with open(allowlist_path, encoding="utf-8") as fh:
    allowed = {
        line.strip()
        for line in fh
        if line.strip() and not line.lstrip().startswith("#")
    }

for dirpath, dirnames, _filenames in os.walk(source_root):
    if ".git" in dirnames:
        rel = os.path.relpath(dirpath, source_root)
        try:
            url = subprocess.check_output(
                ["git", "-C", dirpath, "config", "--get", "remote.origin.url"],
                text=True,
            ).strip()
        except Exception:
            url = ""
        if url in allowed:
            repos.append((rel, url))
        dirnames[:] = []

repos.sort()

with open(manifest_path, "w", encoding="utf-8") as fh:
    fh.write("# relative_path\tremote_url\n")
    for rel, url in repos:
        fh.write(f"{rel}\t{url}\n")

print(f"[go-src-sync] Exported {len(repos)} allowlisted public repos to {manifest_path}")
PY
}

restore_repos() {
  if [[ ! -f "${MANIFEST_PATH}" ]]; then
    echo "[go-src-sync] Manifest not found: ${MANIFEST_PATH}" >&2
    exit 1
  fi

  mkdir -p "${SOURCE_ROOT}"
  local total=0
  local cloned=0
  local skipped=0

  while IFS=$'\t' read -r rel url; do
    [[ -z "${rel}" || "${rel:0:1}" == "#" ]] && continue
    total=$((total + 1))

    if [[ -z "${url}" ]]; then
      skipped=$((skipped + 1))
      echo "[go-src-sync] Skip ${rel}: missing remote url"
      continue
    fi

    local target="${SOURCE_ROOT}/${rel}"
    if [[ -d "${target}/.git" ]]; then
      skipped=$((skipped + 1))
      echo "[go-src-sync] Skip ${rel}: already exists"
      continue
    fi

    if [[ -e "${target}" ]]; then
      skipped=$((skipped + 1))
      echo "[go-src-sync] Skip ${rel}: target exists but not a git repo"
      continue
    fi

    mkdir -p "$(dirname "${target}")"
    echo "[go-src-sync] Cloning ${rel}..."
    if git clone "${url}" "${target}"; then
      cloned=$((cloned + 1))
    else
      skipped=$((skipped + 1))
      echo "[go-src-sync] Failed to clone ${rel}"
    fi
  done < "${MANIFEST_PATH}"

  echo "[go-src-sync] Done: total=${total}, cloned=${cloned}, skipped=${skipped}"
}

main() {
  if [[ $# -ne 1 ]]; then
    usage
    exit 1
  fi

  case "$1" in
    backup) backup_repos ;;
    restore) restore_repos ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
