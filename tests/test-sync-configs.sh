#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_FILTER="${1:-all}"
PASS_COUNT=0
CLEANUP_DIRS=()

cleanup() {
  local path
  for path in "${CLEANUP_DIRS[@]}"; do
    rm -rf "${path}"
  done
}
trap cleanup EXIT

fail() {
  echo "not ok - $1" >&2
  exit 1
}

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  echo "ok ${PASS_COUNT} - $1"
}

assert_file_contains() {
  local file="$1"
  local expected="$2"
  [[ -f "${file}" ]] || fail "missing file: ${file}"
  grep -Fq "${expected}" "${file}" || fail "${file} does not contain expected text"
}

assert_file_not_contains() {
  local file="$1"
  local unexpected="$2"
  [[ -f "${file}" ]] || fail "missing file: ${file}"
  if grep -Fq "${unexpected}" "${file}"; then
    fail "${file} contains sensitive or unexpected text"
  fi
}

assert_path_not_exists() {
  local path="$1"
  if [[ -e "${path}" || -L "${path}" ]]; then
    fail "unexpected path exists: ${path}"
  fi
}

test_zsh_backup_follows_external_symlinks() {
  local test_dir
  test_dir="$(mktemp -d)"
  CLEANUP_DIRS+=("${test_dir}")

  mkdir -p "${test_dir}/repo/dotfiles" "${test_dir}/repo/scripts" "${test_dir}/home" "${test_dir}/old-repo"
  cp "${REPO_ROOT}/sync-zsh-config.sh" "${REPO_ROOT}/dotfiles-link-common.sh" "${test_dir}/repo/"
  cp "${REPO_ROOT}/scripts/config-sanitizer.mjs" "${test_dir}/repo/scripts/"
  printf '%s\n' 'external-zshrc' 'export RELAY_API_KEY="backup-secret"' >"${test_dir}/old-repo/zshrc"
  printf '%s\n' 'external-zprofile' >"${test_dir}/old-repo/zprofile"
  ln -s "${test_dir}/old-repo/zshrc" "${test_dir}/home/.zshrc"
  ln -s "${test_dir}/old-repo/zprofile" "${test_dir}/home/.zprofile"

  HOME="${test_dir}/home" bash "${test_dir}/repo/sync-zsh-config.sh" backup >/dev/null

  assert_file_contains "${test_dir}/repo/dotfiles/.zshrc" 'external-zshrc'
  assert_file_contains "${test_dir}/repo/dotfiles/.zprofile" 'external-zprofile'
  assert_file_contains "${test_dir}/repo/dotfiles/.zshrc" 'export RELAY_API_KEY="__DOTFILES_LOCAL_SECRET__"'
  assert_file_not_contains "${test_dir}/repo/dotfiles/.zshrc" 'backup-secret'

  rm "${test_dir}/home/.zshrc" "${test_dir}/home/.zprofile"
  printf '%s\n' 'old-local-setting' 'export RELAY_API_KEY="local-secret"' >"${test_dir}/home/.zshrc"
  printf '%s\n' 'old-local-profile' >"${test_dir}/home/.zprofile"
  HOME="${test_dir}/home" bash "${test_dir}/repo/sync-zsh-config.sh" restore >/dev/null

  assert_file_contains "${test_dir}/home/.zshrc" 'external-zshrc'
  assert_file_contains "${test_dir}/home/.zshrc" 'export RELAY_API_KEY="local-secret"'
  assert_file_not_contains "${test_dir}/home/.zshrc" '__DOTFILES_LOCAL_SECRET__'
  assert_file_contains "${test_dir}/home/.zshrc.bak.pre-dotfiles" 'old-local-setting'
  [[ ! -L "${test_dir}/home/.zshrc" ]] || fail "mixed zsh config was linked instead of rendered"
  pass "zsh backup sanitizes secrets and restore preserves the local value"
}

test_symlink_restore_preserves_existing_backup() {
  local test_dir
  test_dir="$(mktemp -d)"
  CLEANUP_DIRS+=("${test_dir}")

  mkdir -p "${test_dir}/home" "${test_dir}/repo"
  printf '%s\n' 'managed' >"${test_dir}/repo/config"
  printf '%s\n' 'current' >"${test_dir}/home/config"
  printf '%s\n' 'previous-backup' >"${test_dir}/home/config.bak.pre-dotfiles"

  SOURCE_HELPER="${REPO_ROOT}/dotfiles-link-common.sh" \
    LINK_PATH="${test_dir}/home/config" \
    TARGET_PATH="${test_dir}/repo/config" \
    bash -c 'source "$SOURCE_HELPER"; ensure_symlink "$LINK_PATH" "$TARGET_PATH"' >/dev/null

  assert_file_contains "${test_dir}/home/config.bak.pre-dotfiles" 'previous-backup'
  local extra_backup
  extra_backup="$(find "${test_dir}/home" -maxdepth 1 -type f -name 'config.bak.pre-dotfiles-*' -print -quit)"
  [[ -n "${extra_backup}" ]] || fail "timestamped backup was not created"
  assert_file_contains "${extra_backup}" 'current'
  [[ -L "${test_dir}/home/config" ]] || fail "managed path is not a symlink"
  pass "restore keeps older backups and creates a new timestamped backup"
}

run_zsh_tests() {
  test_zsh_backup_follows_external_symlinks
  test_symlink_restore_preserves_existing_backup
}

test_nvim_backup_excludes_claude_runtime() {
  local test_dir
  test_dir="$(mktemp -d)"
  CLEANUP_DIRS+=("${test_dir}")
  local repo="${test_dir}/repo"
  local home="${test_dir}/home"

  mkdir -p \
    "${repo}/dotfiles/nvim/.claude/worktrees/stale" \
    "${home}/.config/nvim/.claude/worktrees/current"
  cp "${REPO_ROOT}/dotfiles-link-common.sh" "${REPO_ROOT}/sync-nvim-config.sh" "${repo}/"
  printf '%s\n' 'print("portable nvim")' >"${home}/.config/nvim/init.lua"
  printf '%s\n' 'runtime worktree' >"${home}/.config/nvim/.claude/worktrees/current/file.txt"
  printf '%s\n' 'runtime log' >"${home}/.config/nvim/nvim.log"
  printf '%s\n' 'stale runtime' >"${repo}/dotfiles/nvim/.claude/worktrees/stale/file.txt"
  printf '%s\n' 'stale runtime log' >"${repo}/dotfiles/nvim/old.log"

  HOME="${home}" bash "${repo}/sync-nvim-config.sh" backup >/dev/null

  assert_file_contains "${repo}/dotfiles/nvim/init.lua" 'portable nvim'
  assert_path_not_exists "${repo}/dotfiles/nvim/.claude"
  assert_path_not_exists "${repo}/dotfiles/nvim/nvim.log"
  assert_path_not_exists "${repo}/dotfiles/nvim/old.log"
  pass "Neovim backup excludes Claude runtime state"
}

test_nvim_restore_preserves_local_runtime_root() {
  local test_dir
  test_dir="$(mktemp -d)"
  CLEANUP_DIRS+=("${test_dir}")
  local repo="${test_dir}/repo"
  local home="${test_dir}/home"

  mkdir -p \
    "${repo}/dotfiles/nvim/lua/config" \
    "${home}/.config/nvim/.claude/worktrees/current" \
    "${home}/.config/nvim/lua/config"
  cp "${REPO_ROOT}/dotfiles-link-common.sh" "${REPO_ROOT}/sync-nvim-config.sh" "${repo}/"
  printf '%s\n' 'print("managed nvim")' >"${repo}/dotfiles/nvim/init.lua"
  printf '%s\n' 'return {}' >"${repo}/dotfiles/nvim/lua/config/options.lua"
  printf '%s\n' 'print("old nvim")' >"${home}/.config/nvim/init.lua"
  printf '%s\n' 'return { old = true }' >"${home}/.config/nvim/lua/config/options.lua"
  printf '%s\n' 'runtime worktree' >"${home}/.config/nvim/.claude/worktrees/current/file.txt"
  ln -s "${repo}/dotfiles/nvim/removed.log" "${home}/.config/nvim/removed.log"

  HOME="${home}" bash "${repo}/sync-nvim-config.sh" restore >/dev/null

  [[ -d "${home}/.config/nvim" && ! -L "${home}/.config/nvim" ]] || fail "Neovim runtime root was replaced by a symlink"
  assert_file_contains "${home}/.config/nvim/.claude/worktrees/current/file.txt" 'runtime worktree'
  assert_path_not_exists "${home}/.config/nvim/removed.log"
  [[ -L "${home}/.config/nvim/init.lua" ]] || fail "Neovim init.lua is not linked"
  [[ -L "${home}/.config/nvim/lua" ]] || fail "Neovim lua directory is not linked"
  assert_file_contains "${home}/.config/nvim/init.lua.bak.pre-dotfiles" 'old nvim'

  HOME="${home}" bash "${repo}/sync-nvim-config.sh" backup >/dev/null
  [[ -f "${repo}/dotfiles/nvim/init.lua" && ! -L "${repo}/dotfiles/nvim/init.lua" ]] || fail "Neovim backup created a self-referential init.lua link"
  [[ -d "${repo}/dotfiles/nvim/lua" && ! -L "${repo}/dotfiles/nvim/lua" ]] || fail "Neovim backup created a self-referential lua link"
  assert_file_contains "${repo}/dotfiles/nvim/init.lua" 'managed nvim'
  assert_path_not_exists "${repo}/dotfiles/nvim/init.lua.bak.pre-dotfiles"

  rm "${repo}/dotfiles/nvim/init.lua"
  ln -s "${repo}/dotfiles/nvim/init.lua" "${repo}/dotfiles/nvim/init.lua"
  rm -rf "${repo}/dotfiles/nvim/lua"
  ln -s "${repo}/dotfiles/nvim/lua" "${repo}/dotfiles/nvim/lua"
  HOME="${home}" bash "${repo}/sync-nvim-config.sh" backup >/dev/null
  [[ -f "${repo}/dotfiles/nvim/init.lua" && ! -L "${repo}/dotfiles/nvim/init.lua" ]] || fail "Neovim backup did not recover init.lua from the local backup"
  [[ -d "${repo}/dotfiles/nvim/lua" && ! -L "${repo}/dotfiles/nvim/lua" ]] || fail "Neovim backup did not recover lua from the local backup"
  pass "Neovim restore preserves local runtime state"
}

run_nvim_tests() {
  test_nvim_backup_excludes_claude_runtime
  test_nvim_restore_preserves_local_runtime_root
}

test_cursor_backup_only_copies_portable_settings() {
  local test_dir
  test_dir="$(mktemp -d)"
  CLEANUP_DIRS+=("${test_dir}")
  local repo="${test_dir}/repo"
  local home="${test_dir}/home"

  mkdir -p \
    "${repo}/dotfiles/.cursor" \
    "${home}/.cursor/chats" \
    "${home}/.cursor/commands" \
    "${home}/.cursor/extensions" \
    "${home}/.cursor/projects" \
    "${home}/.cursor/rules" \
    "${home}/.cursor/skills/local-skill" \
    "${home}/.cursor/worktrees"
  cp "${REPO_ROOT}/dotfiles-link-common.sh" "${REPO_ROOT}/sync-cursor-config.sh" "${repo}/"

  printf '%s\n' 'portable instructions' >"${home}/.cursor/AGENTS.md"
  printf '%s\n' 'blocked-command' >"${home}/.cursor/blocklist"
  printf '%s\n' 'portable command' >"${home}/.cursor/commands/review.md"
  printf '%s\n' 'portable rule' >"${home}/.cursor/rules/user.mdc"
  printf '%s\n' 'portable skill' >"${home}/.cursor/skills/local-skill/SKILL.md"
  printf '%s\n' '{"hooks":[]}' >"${home}/.cursor/hooks.json"
  printf '%s\n' '{"disable-hardware-acceleration":false}' >"${home}/.cursor/argv.json"
  printf '%s\n' 'runtime chat' >"${home}/.cursor/chats/history.json"
  printf '%s\n' 'runtime extension' >"${home}/.cursor/extensions/extension.bin"
  printf '%s\n' 'runtime project' >"${home}/.cursor/projects/transcript.json"
  printf '%s\n' 'runtime worktree' >"${home}/.cursor/worktrees/file.txt"
  printf '%s\n' '{"machine":"state"}' >"${home}/.cursor/agent-cli-state.json"

  HOME="${home}" bash "${repo}/sync-cursor-config.sh" backup >/dev/null

  assert_file_contains "${repo}/dotfiles/.cursor/AGENTS.md" 'portable instructions'
  assert_file_contains "${repo}/dotfiles/.cursor/blocklist" 'blocked-command'
  assert_file_contains "${repo}/dotfiles/.cursor/argv.json" 'disable-hardware-acceleration'
  assert_path_not_exists "${repo}/dotfiles/.cursor/commands"
  assert_path_not_exists "${repo}/dotfiles/.cursor/rules"
  assert_path_not_exists "${repo}/dotfiles/.cursor/skills"
  assert_path_not_exists "${repo}/dotfiles/.cursor/hooks.json"
  assert_path_not_exists "${repo}/dotfiles/.cursor/chats"
  assert_path_not_exists "${repo}/dotfiles/.cursor/extensions"
  assert_path_not_exists "${repo}/dotfiles/.cursor/projects"
  assert_path_not_exists "${repo}/dotfiles/.cursor/worktrees"
  assert_path_not_exists "${repo}/dotfiles/.cursor/agent-cli-state.json"
  pass "Cursor backup copies only the explicit public allowlist"
}

test_cursor_restore_preserves_runtime_root_and_local_skills() {
  local test_dir
  test_dir="$(mktemp -d)"
  CLEANUP_DIRS+=("${test_dir}")
  local repo="${test_dir}/repo"
  local home="${test_dir}/home"

  mkdir -p \
    "${repo}/dotfiles/.cursor" \
    "${home}/.cursor/chats" \
    "${home}/.cursor/commands" \
    "${home}/.cursor/extensions" \
    "${home}/.cursor/skills/local-skill"
  cp "${REPO_ROOT}/dotfiles-link-common.sh" "${REPO_ROOT}/sync-cursor-config.sh" "${repo}/"

  printf '%s\n' 'managed instructions' >"${repo}/dotfiles/.cursor/AGENTS.md"
  printf '%s\n' '{"disable-hardware-acceleration":false}' >"${repo}/dotfiles/.cursor/argv.json"
  printf '%s\n' 'old command' >"${home}/.cursor/commands/old.md"
  printf '%s\n' '{"hooks":["old"]}' >"${home}/.cursor/hooks.json"
  printf '%s\n' 'runtime chat' >"${home}/.cursor/chats/history.json"
  printf '%s\n' 'runtime extension' >"${home}/.cursor/extensions/extension.bin"
  printf '%s\n' 'old local skill' >"${home}/.cursor/skills/local-skill/SKILL.md"

  HOME="${home}" bash "${repo}/sync-cursor-config.sh" restore >/dev/null

  [[ -d "${home}/.cursor" && ! -L "${home}/.cursor" ]] || fail "Cursor runtime root was replaced by a symlink"
  assert_file_contains "${home}/.cursor/chats/history.json" 'runtime chat'
  assert_file_contains "${home}/.cursor/extensions/extension.bin" 'runtime extension'
  assert_file_contains "${home}/.cursor/commands/old.md" 'old command'
  assert_file_contains "${home}/.cursor/hooks.json" '"old"'
  assert_file_contains "${home}/.cursor/skills/local-skill/SKILL.md" 'old local skill'
  [[ -L "${home}/.cursor/AGENTS.md" ]] || fail "Cursor instructions file is not linked"
  [[ -L "${home}/.cursor/argv.json" ]] || fail "Cursor argv file is not linked"

  HOME="${home}" bash "${repo}/sync-cursor-config.sh" backup >/dev/null
  assert_file_contains "${repo}/dotfiles/.cursor/AGENTS.md" 'managed instructions'
  assert_path_not_exists "${repo}/dotfiles/.cursor/commands"
  assert_path_not_exists "${repo}/dotfiles/.cursor/skills"
  pass "Cursor restore preserves runtime state and local-only configuration"
}

run_cursor_tests() {
  test_cursor_backup_only_copies_portable_settings
  test_cursor_restore_preserves_runtime_root_and_local_skills
}

test_agents_backup_avoids_repo_self_sync_and_runtime_state() {
  local test_dir
  test_dir="$(mktemp -d)"
  CLEANUP_DIRS+=("${test_dir}")
  local repo="${test_dir}/repo"
  local home="${test_dir}/home"

  mkdir -p "${repo}/dotfiles/.agents/skills/existing" "${home}/.agents"
  cp "${REPO_ROOT}/dotfiles-link-common.sh" "${REPO_ROOT}/sync-agents-config.sh" "${repo}/"
  printf '%s\n' 'existing skill' >"${repo}/dotfiles/.agents/skills/existing/SKILL.md"
  printf '%s\n' 'portable agent instructions' >"${home}/.agents/agents.md"
  printf '%s\n' '{"token":"local-only"}' >"${home}/.agents/auth.json"
  printf '%s\n' '{"runtime":true}' >"${home}/.agents/.skill-lock.json"
  ln -s "${repo}/dotfiles/.agents/skills" "${home}/.agents/skills"

  HOME="${home}" bash "${repo}/sync-agents-config.sh" backup >/dev/null

  assert_file_contains "${repo}/dotfiles/.agents/agents.md" 'portable agent instructions'
  assert_file_contains "${repo}/dotfiles/.agents/skills/existing/SKILL.md" 'existing skill'
  assert_path_not_exists "${repo}/dotfiles/.agents/auth.json"
  assert_path_not_exists "${repo}/dotfiles/.agents/.skill-lock.json"
  pass "Agents backup leaves skills and runtime state untouched"
}

test_agents_backup_does_not_copy_skills() {
  local test_dir
  test_dir="$(mktemp -d)"
  CLEANUP_DIRS+=("${test_dir}")
  local repo="${test_dir}/repo"
  local home="${test_dir}/home"

  mkdir -p "${repo}" "${home}/.agents/skills/demo"
  cp "${REPO_ROOT}/dotfiles-link-common.sh" "${REPO_ROOT}/sync-agents-config.sh" "${repo}/"
  printf '%s\n' 'portable agent instructions' >"${home}/.agents/agents.md"
  printf '%s\n' 'demo skill' >"${home}/.agents/skills/demo/SKILL.md"

  HOME="${home}" bash "${repo}/sync-agents-config.sh" backup >/dev/null

  assert_file_contains "${repo}/dotfiles/.agents/agents.md" 'portable agent instructions'
  assert_path_not_exists "${repo}/dotfiles/.agents/skills"
  pass "Agents backup does not copy skills"
}

test_agents_restore_preserves_runtime_root() {
  local test_dir
  test_dir="$(mktemp -d)"
  CLEANUP_DIRS+=("${test_dir}")
  local repo="${test_dir}/repo"
  local home="${test_dir}/home"

  mkdir -p "${repo}/dotfiles/.agents" "${home}/.agents/skills"
  cp "${REPO_ROOT}/dotfiles-link-common.sh" "${REPO_ROOT}/sync-agents-config.sh" "${repo}/"
  printf '%s\n' 'managed instructions' >"${repo}/dotfiles/.agents/agents.md"
  printf '%s\n' '{"token":"local-only"}' >"${home}/.agents/auth.json"
  printf '%s\n' 'old skill' >"${home}/.agents/skills/old.txt"

  HOME="${home}" bash "${repo}/sync-agents-config.sh" restore >/dev/null

  [[ -d "${home}/.agents" && ! -L "${home}/.agents" ]] || fail "Agents runtime root was replaced by a symlink"
  assert_file_contains "${home}/.agents/auth.json" 'local-only'
  [[ -d "${home}/.agents/skills" && ! -L "${home}/.agents/skills" ]] || fail "Agents skills directory was replaced"
  assert_file_contains "${home}/.agents/skills/old.txt" 'old skill'
  [[ -L "${home}/.agents/agents.md" ]] || fail "Agents instructions are not linked"

  HOME="${home}" bash "${repo}/sync-agents-config.sh" backup >/dev/null
  assert_file_contains "${repo}/dotfiles/.agents/agents.md" 'managed instructions'
  local backups_before
  local backups_after
  backups_before="$(find "${home}/.agents" -mindepth 1 -maxdepth 1 -name '*.bak.pre-dotfiles*' | sort)"
  HOME="${home}" bash "${repo}/sync-agents-config.sh" restore >/dev/null
  backups_after="$(find "${home}/.agents" -mindepth 1 -maxdepth 1 -name '*.bak.pre-dotfiles*' | sort)"
  [[ "${backups_before}" == "${backups_after}" ]] || fail "second Agents restore created new backups"
  pass "Agents restore preserves runtime root and credentials"
}

run_agents_tests() {
  test_agents_backup_avoids_repo_self_sync_and_runtime_state
  test_agents_backup_does_not_copy_skills
  test_agents_restore_preserves_runtime_root
}

test_gitconfig_backup_exports_only_public_settings() {
  local test_dir
  test_dir="$(mktemp -d)"
  CLEANUP_DIRS+=("${test_dir}")
  local repo="${test_dir}/repo"
  local home="${test_dir}/home"

  mkdir -p "${repo}/dotfiles" "${home}"
  cp "${REPO_ROOT}/dotfiles-link-common.sh" "${REPO_ROOT}/sync-gitconfig.sh" "${repo}/"
  git config --file "${home}/.gitconfig" user.name "Private User"
  git config --file "${home}/.gitconfig" user.email "private@example.invalid"
  git config --file "${home}/.gitconfig" http.sslVerify false
  git config --file "${home}/.gitconfig" init.defaultBranch main
  git config --file "${home}/.gitconfig" core.editor nvim

  HOME="${home}" GIT_CONFIG_GLOBAL="${home}/.gitconfig" bash "${repo}/sync-gitconfig.sh" backup >/dev/null

  assert_file_contains "${repo}/dotfiles/.gitconfig" 'defaultBranch = main'
  assert_file_contains "${repo}/dotfiles/.gitconfig" 'editor = nvim'
  assert_file_not_contains "${repo}/dotfiles/.gitconfig" 'Private User'
  assert_file_not_contains "${repo}/dotfiles/.gitconfig" 'private@example.invalid'
  assert_file_not_contains "${repo}/dotfiles/.gitconfig" 'sslVerify'
  pass "Git config backup exports only allowlisted public settings"
}

test_go_repo_backup_requires_an_explicit_allowlist() {
  local test_dir
  test_dir="$(mktemp -d)"
  CLEANUP_DIRS+=("${test_dir}")
  local repo="${test_dir}/repo"
  local home="${test_dir}/home"
  local allowlist="${test_dir}/public-remotes.txt"

  mkdir -p "${repo}" "${home}/go_repos/src/public/repo" "${home}/go_repos/src/private/repo"
  cp "${REPO_ROOT}/sync-go-src-repos.sh" "${repo}/"
  git -C "${home}/go_repos/src/public/repo" init -q
  git -C "${home}/go_repos/src/public/repo" remote add origin https://github.com/example/public.git
  git -C "${home}/go_repos/src/private/repo" init -q
  git -C "${home}/go_repos/src/private/repo" remote add origin ssh://git@private.example.invalid/team/private.git
  printf '%s\n' 'https://github.com/example/public.git' >"${allowlist}"

  HOME="${home}" PUBLIC_GO_REPOS_ALLOWLIST="${allowlist}" bash "${repo}/sync-go-src-repos.sh" backup >/dev/null

  assert_file_contains "${repo}/dotfiles/go/src_repos_manifest.tsv" 'https://github.com/example/public.git'
  assert_file_not_contains "${repo}/dotfiles/go/src_repos_manifest.tsv" 'private.example.invalid'
  pass "Go repository backup exports only explicitly allowlisted remotes"
}

run_public_sync_tests() {
  test_gitconfig_backup_exports_only_public_settings
  test_go_repo_backup_requires_an_explicit_allowlist
}

test_lark_channel_restore_keeps_runtime_root_when_snapshot_is_empty() {
  local test_dir
  test_dir="$(mktemp -d)"
  CLEANUP_DIRS+=("${test_dir}")
  local repo="${test_dir}/repo"
  local home="${test_dir}/home"

  mkdir -p "${repo}/dotfiles/.lark-channel" "${home}/.lark-channel/logs"
  cp "${REPO_ROOT}/dotfiles-link-common.sh" "${REPO_ROOT}/sync-lark-channel-config.sh" "${repo}/"
  printf '%s\n' 'runtime log' >"${home}/.lark-channel/logs/current.log"
  printf '%s\n' '/logs/' >"${repo}/dotfiles/.lark-channel/.gitignore"

  HOME="${home}" bash "${repo}/sync-lark-channel-config.sh" restore >/dev/null

  [[ -d "${home}/.lark-channel" && ! -L "${home}/.lark-channel" ]] || fail "empty Lark snapshot replaced the runtime root"
  assert_file_contains "${home}/.lark-channel/logs/current.log" 'runtime log'
  pass "empty Lark snapshot leaves the runtime root in place"
}

run_lark_channel_tests() {
  test_lark_channel_restore_keeps_runtime_root_when_snapshot_is_empty
}

test_macos_restore_skips_when_settings_are_already_synced() {
  local test_dir
  test_dir="$(mktemp -d)"
  CLEANUP_DIRS+=("${test_dir}")
  local repo="${test_dir}/repo"
  local home="${test_dir}/home"
  local fake_bin="${test_dir}/bin"
  local log="${test_dir}/node.log"

  mkdir -p "${repo}/scripts" "${repo}/dotfiles/macos" "${home}" "${fake_bin}"
  cp "${REPO_ROOT}/sync-macos-settings.sh" "${repo}/"
  printf '%s\n' '# placeholder' >"${repo}/scripts/macos-settings.mjs"
  printf '%s\n' '{"version":1,"domains":{}}' >"${repo}/dotfiles/macos/settings.json"
  printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" "$*" >>"$MACOS_TEST_LOG"' 'exit 0' >"${fake_bin}/node"
  printf '%s\n' '#!/usr/bin/env bash' 'echo Darwin' >"${fake_bin}/uname"
  chmod +x "${fake_bin}/node" "${fake_bin}/uname"

  HOME="${home}" PATH="${fake_bin}:${PATH}" MACOS_TEST_LOG="${log}" DOTFILES_SKIP_RESTART=1 \
    bash "${repo}/sync-macos-settings.sh" restore >/dev/null

  [[ "$(wc -l <"${log}" | tr -d ' ')" == "1" ]] || fail "synced macOS restore performed backup or writes"
  assert_file_contains "${log}" 'status'
  assert_path_not_exists "${home}/Library/Application Support/bytedotfiles/backups"
  pass "macOS restore skips writes and rollback backup when already synced"
}

run_macos_tests() {
  test_macos_restore_skips_when_settings_are_already_synced
}

test_ai_app_backup_and_restore() {
  local test_dir
  test_dir="$(mktemp -d)"
  CLEANUP_DIRS+=("${test_dir}")
  local repo="${test_dir}/repo"
  local home="${test_dir}/home"

  mkdir -p \
    "${repo}/scripts" \
    "${repo}/dotfiles/codex/rules" \
    "${repo}/dotfiles/traex" \
    "${repo}/dotfiles/claude" \
    "${repo}/dotfiles/ghostty" \
    "${home}/.codex/rules" \
    "${home}/.trae/cli" \
    "${home}/.claude" \
    "${home}/.config/ghostty" \
    "${home}/Library/Application Support/Claude-3p"
  cp "${REPO_ROOT}/scripts/config-sanitizer.mjs" "${repo}/scripts/"
  cp "${REPO_ROOT}/dotfiles-link-common.sh" "${repo}/"
  cp "${REPO_ROOT}/sync-ai-app-configs.sh" "${repo}/"

  cat >"${repo}/dotfiles/codex/config.toml" <<'EOF'
model = "portable-codex-model"
notify = ["__DOTFILES_HOME__/bin/notify"]
[model_providers.gateway.http_headers]
X-Llmgw-Authorization = "__DOTFILES_LOCAL_SECRET__"
EOF
  printf '%s\n' 'codex instructions' >"${repo}/dotfiles/codex/AGENTS.md"
  printf '%s\n' 'allow_rule("__DOTFILES_HOME__/bin/rule")' >"${repo}/dotfiles/codex/rules/default.rules"
  printf '%s\n' '{"hooks":[]}' >"${repo}/dotfiles/codex/hooks.json"

  cat >"${repo}/dotfiles/traex/traecli.toml" <<'EOF'
model = "portable-traex-model"
[provider]
auth_token = "__DOTFILES_LOCAL_SECRET__"
EOF
  printf '%s\n' 'notify = true' >"${repo}/dotfiles/traex/cli-config.toml"

  cat >"${repo}/dotfiles/claude/settings.json" <<'EOF'
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "__DOTFILES_LOCAL_SECRET__",
    "ANTHROPIC_BASE_URL": "https://portable.invalid"
  },
  "model": "portable-claude-model"
}
EOF
  printf '%s\n' 'claude instructions' >"${repo}/dotfiles/claude/CLAUDE.md"
  printf '%s\n' 'shared agent instructions' >"${repo}/dotfiles/claude/AGENTS.md"
  cat >"${repo}/dotfiles/claude/desktop-Claude-3p.json" <<'EOF'
{
  "deploymentMode": "default",
  "preferences": {"menuBarEnabled": true},
  "mcpServers": {
    "demo": {
      "command": "__DOTFILES_HOME__/bin/demo-mcp",
      "env": {"API_KEY": "__DOTFILES_LOCAL_SECRET__"}
    }
  }
}
EOF
  printf '%s\n' 'font-family = "Test Mono"' 'font-size = 14' >"${repo}/dotfiles/ghostty/config"

  cat >"${home}/.codex/config.toml" <<'EOF'
model = "portable-codex-model"
notify = ["/Users/tester/bin/notify"]
[model_providers.gateway.http_headers]
X-Llmgw-Authorization = "Bearer codex-backup-secret"
EOF
  printf '%s\n' 'codex instructions' >"${home}/.codex/AGENTS.md"
  printf '%s\n' "allow_rule(\"${home}/bin/rule\")" >"${home}/.codex/rules/default.rules"
  printf '%s\n' '{"hooks":[]}' >"${home}/.codex/hooks.json"

  cat >"${home}/.trae/traecli.toml" <<'EOF'
model = "portable-traex-model"
[provider]
auth_token = "traex-backup-secret"
EOF
  printf '%s\n' 'notify = true' >"${home}/.trae/cli/config.toml"

  cat >"${home}/.claude/settings.json" <<'EOF'
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "claude-backup-secret",
    "ANTHROPIC_BASE_URL": "https://portable.invalid"
  },
  "model": "portable-claude-model"
}
EOF
  printf '%s\n' 'claude instructions' >"${home}/.claude/CLAUDE.md"
  printf '%s\n' 'shared agent instructions' >"${home}/.claude/AGENTS.md"

  cat >"${home}/Library/Application Support/Claude-3p/claude_desktop_config.json" <<'EOF'
{
  "deploymentMode": "default",
  "preferences": {
    "menuBarEnabled": true,
    "lastKnownAccountUuid": "account-backup",
    "localAgentModeTrustedFolders": ["/Users/tester/private"]
  },
  "mcpServers": {
    "demo": {
      "command": "/Users/tester/bin/demo-mcp",
      "env": {"API_KEY": "mcp-backup-secret"}
    }
  },
  "oauth:tokenCache": "oauth-backup-secret"
}
EOF
  printf '%s\n' 'font-family = "Test Mono"' 'font-size = 14' >"${home}/.config/ghostty/config"

  HOME="${home}" bash "${repo}/sync-ai-app-configs.sh" backup >/dev/null

  assert_file_contains "${repo}/dotfiles/codex/config.toml" 'X-Llmgw-Authorization = "__DOTFILES_LOCAL_SECRET__"'
  assert_file_not_contains "${repo}/dotfiles/codex/config.toml" 'codex-backup-secret'
  assert_file_contains "${repo}/dotfiles/codex/rules/default.rules" '__DOTFILES_HOME__/bin/rule'
  assert_file_not_contains "${repo}/dotfiles/codex/rules/default.rules" "${home}"
  assert_file_contains "${repo}/dotfiles/traex/traecli.toml" 'auth_token = "__DOTFILES_LOCAL_SECRET__"'
  assert_file_not_contains "${repo}/dotfiles/traex/traecli.toml" 'traex-backup-secret'
  assert_file_contains "${repo}/dotfiles/claude/settings.json" '"ANTHROPIC_AUTH_TOKEN": "__DOTFILES_LOCAL_SECRET__"'
  assert_file_not_contains "${repo}/dotfiles/claude/settings.json" 'claude-backup-secret'
  assert_file_contains "${repo}/dotfiles/claude/desktop-Claude-3p.json" '"API_KEY": "__DOTFILES_LOCAL_SECRET__"'
  assert_file_not_contains "${repo}/dotfiles/claude/desktop-Claude-3p.json" 'account-backup'
  assert_file_not_contains "${repo}/dotfiles/claude/desktop-Claude-3p.json" 'private'
  assert_file_contains "${repo}/dotfiles/ghostty/config" 'font-size = 14'

  cat >"${home}/.codex/config.toml" <<'EOF'
model = "old-codex-model"
[model_providers.gateway.http_headers]
X-Llmgw-Authorization = "Bearer codex-local-secret"
EOF
  cat >"${home}/.trae/traecli.toml" <<'EOF'
model = "old-traex-model"
[provider]
auth_token = "traex-local-secret"
EOF
  cat >"${home}/.claude/settings.json" <<'EOF'
{
  "env": {"ANTHROPIC_AUTH_TOKEN": "claude-local-secret"},
  "model": "old-claude-model"
}
EOF
  cat >"${home}/Library/Application Support/Claude-3p/claude_desktop_config.json" <<'EOF'
{
  "preferences": {"menuBarEnabled": false, "lastKnownAccountUuid": "account-local"},
  "mcpServers": {"demo": {"env": {"API_KEY": "mcp-local-secret"}}},
  "oauth:tokenCache": "oauth-local-secret"
}
EOF

  HOME="${home}" bash "${repo}/sync-ai-app-configs.sh" restore >/dev/null

  assert_file_contains "${home}/.codex/config.toml" 'model = "portable-codex-model"'
  assert_file_contains "${home}/.codex/config.toml" 'X-Llmgw-Authorization = "Bearer codex-local-secret"'
  assert_file_contains "${home}/.trae/traecli.toml" 'model = "portable-traex-model"'
  assert_file_contains "${home}/.trae/traecli.toml" 'auth_token = "traex-local-secret"'
  assert_file_contains "${home}/.codex/config.toml.bak.pre-dotfiles" 'model = "old-codex-model"'
  assert_file_contains "${home}/.trae/traecli.toml.bak.pre-dotfiles" 'model = "old-traex-model"'
  assert_file_contains "${home}/.claude/settings.json.bak.pre-dotfiles" '"model": "old-claude-model"'
  node - <<'NODE' "${home}/.claude/settings.json" "${home}/Library/Application Support/Claude-3p/claude_desktop_config.json"
const fs = require('fs');
const settings = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const desktop = JSON.parse(fs.readFileSync(process.argv[3], 'utf8'));
if (settings.env.ANTHROPIC_AUTH_TOKEN !== 'claude-local-secret') process.exit(1);
if (settings.model !== 'portable-claude-model') process.exit(1);
if (desktop.preferences.menuBarEnabled !== true) process.exit(1);
if (desktop.preferences.lastKnownAccountUuid !== 'account-local') process.exit(1);
if (desktop.mcpServers.demo.env.API_KEY !== 'mcp-local-secret') process.exit(1);
if (desktop['oauth:tokenCache'] !== 'oauth-local-secret') process.exit(1);
NODE
  [[ -L "${home}/.config/ghostty/config" ]] || fail "Ghostty config is not linked to the repository"
  [[ "$(readlink "${home}/.config/ghostty/config")" == "${repo}/dotfiles/ghostty/config" ]] || fail "Ghostty config points to the wrong target"
  [[ -L "${home}/.codex/AGENTS.md" ]] || fail "Codex AGENTS.md is not linked"
  [[ ! -L "${home}/.codex/rules" ]] || fail "Codex rules marker templates were linked without rendering"
  assert_file_contains "${home}/.codex/rules/default.rules" "${home}/bin/rule"
  assert_file_not_contains "${home}/.codex/rules/default.rules" '__DOTFILES_HOME__'
  [[ -L "${home}/.claude/CLAUDE.md" ]] || fail "Claude CLAUDE.md is not linked"
  HOME="${home}" bash "${repo}/sync-ai-app-configs.sh" status >/dev/null
  HOME="${home}" bash "${repo}/sync-ai-app-configs.sh" backup >/dev/null
  assert_file_contains "${repo}/dotfiles/codex/AGENTS.md" 'codex instructions'
  assert_file_contains "${repo}/dotfiles/claude/CLAUDE.md" 'claude instructions'
  assert_file_contains "${repo}/dotfiles/ghostty/config" 'font-size = 14'
  pass "AI app backup stays disabled and restore preserves local credentials"
}

run_ai_app_tests() {
  test_ai_app_backup_and_restore
}

setup_orchestrator_fixture() {
  local repo="$1"
  mkdir -p "${repo}"
  cp "${REPO_ROOT}/sync-dev-configs.sh" "${repo}/"

  local script
  for script in \
    sync-zsh-config.sh \
    sync-gitconfig.sh \
    sync-nvim-config.sh \
    sync-karabiner-config.sh \
    sync-cursor-config.sh \
    sync-lark-channel-config.sh \
    sync-agents-config.sh \
    sync-go-src-repos.sh \
    sync-ai-app-configs.sh \
    sync-macos-settings.sh \
    sync-ssh-key.sh; do
    printf '%s\n' \
      '#!/usr/bin/env bash' \
      'name="$(basename "$0")"' \
      'printf "%s %s\n" "$name" "$1" >>"$SYNC_TEST_LOG"' \
      'if [[ "${FAIL_STEP:-}" == "$name" ]]; then exit 7; fi' \
      >"${repo}/${script}"
    chmod +x "${repo}/${script}"
  done
  chmod +x "${repo}/sync-dev-configs.sh"
}

test_orchestrator_runs_macos_steps_in_order_without_ssh() {
  local test_dir
  test_dir="$(mktemp -d)"
  CLEANUP_DIRS+=("${test_dir}")
  setup_orchestrator_fixture "${test_dir}/repo"
  local log="${test_dir}/calls.log"

  SYNC_TEST_LOG="${log}" DOTFILES_PLATFORM=Darwin \
    bash "${test_dir}/repo/sync-dev-configs.sh" backup >/dev/null

  local expected="${test_dir}/expected.log"
  printf '%s\n' \
    'sync-zsh-config.sh backup' \
    'sync-gitconfig.sh backup' \
    'sync-nvim-config.sh backup' \
    'sync-karabiner-config.sh backup' \
    'sync-cursor-config.sh backup' \
    'sync-lark-channel-config.sh backup' \
    'sync-agents-config.sh backup' \
    'sync-go-src-repos.sh backup' \
    'sync-ai-app-configs.sh backup' \
    'sync-macos-settings.sh backup' \
    >"${expected}"
  cmp -s "${log}" "${expected}" || fail "macOS sync order is incorrect"
  assert_file_not_contains "${log}" 'sync-ssh-key.sh'
  pass "orchestrator runs macOS steps in order and keeps SSH key sync explicit"
}

test_orchestrator_skips_macos_only_steps_elsewhere() {
  local test_dir
  test_dir="$(mktemp -d)"
  CLEANUP_DIRS+=("${test_dir}")
  setup_orchestrator_fixture "${test_dir}/repo"
  local log="${test_dir}/calls.log"

  SYNC_TEST_LOG="${log}" DOTFILES_PLATFORM=Linux \
    bash "${test_dir}/repo/sync-dev-configs.sh" restore >/dev/null

  assert_file_not_contains "${log}" 'sync-karabiner-config.sh'
  assert_file_not_contains "${log}" 'sync-macos-settings.sh'
  assert_file_contains "${log}" 'sync-ai-app-configs.sh restore'
  pass "orchestrator skips macOS-only steps on other platforms"
}

test_orchestrator_continues_and_reports_failures() {
  local test_dir
  test_dir="$(mktemp -d)"
  CLEANUP_DIRS+=("${test_dir}")
  setup_orchestrator_fixture "${test_dir}/repo"
  local log="${test_dir}/calls.log"
  local output="${test_dir}/output.log"

  set +e
  SYNC_TEST_LOG="${log}" DOTFILES_PLATFORM=Darwin FAIL_STEP=sync-gitconfig.sh \
    bash "${test_dir}/repo/sync-dev-configs.sh" backup >"${output}" 2>&1
  local status=$?
  set -e

  [[ "${status}" -ne 0 ]] || fail "orchestrator returned success after a failed step"
  assert_file_contains "${log}" 'sync-nvim-config.sh backup'
  assert_file_contains "${output}" 'Failed steps: git'
  pass "orchestrator continues independent work and reports failed steps"
}

test_bootstrap_restores_ai_apps_before_macos_settings() {
  local bootstrap="${REPO_ROOT}/bootstrap-mac.sh"
  local ai_line
  local macos_line
  ai_line="$(rg -n 'sync-ai-app-configs\.sh.*restore|restore_ai_app_configs' "${bootstrap}" | tail -1 | cut -d: -f1 || true)"
  macos_line="$(rg -n 'sync-macos-settings\.sh.*restore|restore_macos_settings' "${bootstrap}" | tail -1 | cut -d: -f1 || true)"
  [[ -n "${ai_line}" ]] || fail "bootstrap does not restore AI app settings"
  [[ -n "${macos_line}" ]] || fail "bootstrap does not restore macOS settings"
  [[ "${ai_line}" -lt "${macos_line}" ]] || fail "bootstrap restores macOS settings before AI app settings"
  pass "bootstrap restores AI app settings before macOS settings"
}

assert_bootstrap_uses_portable_cursor_restore() {
  local bootstrap="$1"
  local function_body
  function_body="$(sed -n '/^link_cursor_config()/,/^}/p' "${bootstrap}")"

  grep -Fq 'sync-cursor-config.sh' <<<"${function_body}" || fail "$(basename "${bootstrap}") does not locate the portable Cursor sync script"
  grep -Fq '"${sync_script}" restore' <<<"${function_body}" || fail "$(basename "${bootstrap}") does not delegate to portable Cursor restore"
  if grep -Fq 'ensure_symlink "${source_cursor_dir}"' <<<"${function_body}"; then
    fail "$(basename "${bootstrap}") still replaces the Cursor runtime root"
  fi
}

test_bootstraps_use_portable_cursor_restore() {
  assert_bootstrap_uses_portable_cursor_restore "${REPO_ROOT}/bootstrap-mac.sh"
  assert_bootstrap_uses_portable_cursor_restore "${REPO_ROOT}/bootstrap-debian.sh"
  pass "bootstrap uses portable Cursor restore without replacing the runtime root"
}

assert_bootstrap_uses_portable_agents_restore() {
  local bootstrap="$1"
  local function_body
  function_body="$(sed -n '/^link_agents_config()/,/^}/p' "${bootstrap}")"

  grep -Fq 'sync-agents-config.sh' <<<"${function_body}" || fail "$(basename "${bootstrap}") does not locate the portable Agents sync script"
  grep -Fq '"${sync_script}" restore' <<<"${function_body}" || fail "$(basename "${bootstrap}") does not delegate to portable Agents restore"
  if grep -Fq 'ensure_symlink "${source_agents_dir}"' <<<"${function_body}"; then
    fail "$(basename "${bootstrap}") still replaces the Agents runtime root"
  fi
}

test_bootstraps_use_portable_agents_restore() {
  assert_bootstrap_uses_portable_agents_restore "${REPO_ROOT}/bootstrap-mac.sh"
  assert_bootstrap_uses_portable_agents_restore "${REPO_ROOT}/bootstrap-debian.sh"
  pass "bootstrap uses portable Agents restore without replacing the runtime root"
}

assert_bootstrap_uses_secret_safe_zsh_restore() {
  local bootstrap="$1"
  local function_body
  function_body="$(sed -n '/^link_zsh_config()/,/^}/p' "${bootstrap}")"

  grep -Fq 'sync-zsh-config.sh' <<<"${function_body}" || fail "$(basename "${bootstrap}") does not locate the secret-safe zsh sync script"
  grep -Fq '"${sync_script}" restore' <<<"${function_body}" || fail "$(basename "${bootstrap}") does not delegate to secret-safe zsh restore"
  if grep -Fq 'ensure_symlink "${HOME}/.zshrc"' <<<"${function_body}"; then
    fail "$(basename "${bootstrap}") still links the mixed zsh config directly"
  fi
}

test_bootstraps_use_secret_safe_zsh_restore() {
  assert_bootstrap_uses_secret_safe_zsh_restore "${REPO_ROOT}/bootstrap-mac.sh"
  assert_bootstrap_uses_secret_safe_zsh_restore "${REPO_ROOT}/bootstrap-debian.sh"
  pass "bootstrap uses secret-safe zsh restore"
}

assert_bootstrap_uses_safe_lark_restore() {
  local bootstrap="$1"
  local function_body
  function_body="$(sed -n '/^link_lark_channel_config()/,/^}/p' "${bootstrap}")"

  grep -Fq 'sync-lark-channel-config.sh' <<<"${function_body}" || fail "$(basename "${bootstrap}") does not locate the safe Lark sync script"
  grep -Fq '"${sync_script}" restore' <<<"${function_body}" || fail "$(basename "${bootstrap}") does not delegate to safe Lark restore"
  if grep -Fq 'ensure_symlink "${source_lark_channel_dir}"' <<<"${function_body}"; then
    fail "$(basename "${bootstrap}") still replaces the Lark runtime root directly"
  fi
}

test_bootstraps_use_safe_lark_restore() {
  assert_bootstrap_uses_safe_lark_restore "${REPO_ROOT}/bootstrap-mac.sh"
  assert_bootstrap_uses_safe_lark_restore "${REPO_ROOT}/bootstrap-debian.sh"
  pass "bootstrap uses safe Lark restore"
}

assert_bootstrap_uses_runtime_safe_nvim_restore() {
  local bootstrap="$1"
  local function_body
  function_body="$(sed -n '/^link_nvim_config()/,/^}/p' "${bootstrap}")"

  grep -Fq 'sync-nvim-config.sh' <<<"${function_body}" || fail "$(basename "${bootstrap}") does not locate the runtime-safe Neovim sync script"
  grep -Fq '"${sync_script}" restore' <<<"${function_body}" || fail "$(basename "${bootstrap}") does not delegate to runtime-safe Neovim restore"
  if grep -Fq 'ensure_symlink "${target_nvim_dir}"' <<<"${function_body}"; then
    fail "$(basename "${bootstrap}") still replaces the Neovim runtime root directly"
  fi
}

test_bootstraps_use_runtime_safe_nvim_restore() {
  assert_bootstrap_uses_runtime_safe_nvim_restore "${REPO_ROOT}/bootstrap-mac.sh"
  assert_bootstrap_uses_runtime_safe_nvim_restore "${REPO_ROOT}/bootstrap-debian.sh"
  pass "bootstrap uses runtime-safe Neovim restore"
}

run_orchestrator_tests() {
  test_orchestrator_runs_macos_steps_in_order_without_ssh
  test_orchestrator_skips_macos_only_steps_elsewhere
  test_orchestrator_continues_and_reports_failures
  test_bootstrap_restores_ai_apps_before_macos_settings
  test_bootstraps_use_portable_cursor_restore
  test_bootstraps_use_portable_agents_restore
  test_bootstraps_use_secret_safe_zsh_restore
  test_bootstraps_use_safe_lark_restore
  test_bootstraps_use_runtime_safe_nvim_restore
}

case "${TEST_FILTER}" in
  all)
    run_zsh_tests
    run_nvim_tests
    run_cursor_tests
    run_agents_tests
    run_public_sync_tests
    run_lark_channel_tests
    run_macos_tests
    run_ai_app_tests
    run_orchestrator_tests
    ;;
  zsh) run_zsh_tests ;;
  nvim) run_nvim_tests ;;
  cursor) run_cursor_tests ;;
  agents) run_agents_tests ;;
  public-sync) run_public_sync_tests ;;
  lark-channel) run_lark_channel_tests ;;
  macos) run_macos_tests ;;
  ai-apps) run_ai_app_tests ;;
  orchestrator) run_orchestrator_tests ;;
  *) fail "unknown test filter: ${TEST_FILTER}" ;;
esac

echo "${PASS_COUNT} tests passed"
