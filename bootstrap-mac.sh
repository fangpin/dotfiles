#!/usr/bin/env bash
set +e
# Later steps still run if a command fails (homebrew, curl, etc.).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=dotfiles-link-common.sh
source "${SCRIPT_DIR}/dotfiles-link-common.sh"

BREWFILE="${SCRIPT_DIR}/Brewfile"
NERD_FONTS_BREWFILE="${SCRIPT_DIR}/Brewfile.nerd-fonts"
KARABINER_DOTFILES_DIR="${SCRIPT_DIR}/dotfiles/karabiner"

activate_homebrew() {
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    return
  fi

  if [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
    return
  fi
}

install_oh_my_zsh_plugins() {
  if [[ ! -d "${HOME}/.oh-my-zsh" ]]; then
    echo "[bootstrap] Oh My Zsh not found, installing..."
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \
      "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  fi

  local custom_plugins_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
  mkdir -p "${custom_plugins_dir}"

  if [[ ! -d "${custom_plugins_dir}/zsh-autosuggestions" ]]; then
    echo "[bootstrap] Installing zsh-autosuggestions..."
    git clone --depth=1 \
      https://github.com/zsh-users/zsh-autosuggestions \
      "${custom_plugins_dir}/zsh-autosuggestions"
  fi

  if [[ ! -d "${custom_plugins_dir}/zsh-syntax-highlighting" ]]; then
    echo "[bootstrap] Installing zsh-syntax-highlighting..."
    git clone --depth=1 \
      https://github.com/zsh-users/zsh-syntax-highlighting \
      "${custom_plugins_dir}/zsh-syntax-highlighting"
  fi
}

setup_go_repos() {
  local go_repos_dir="${HOME}/go_repos"
  local go_bin_dir="${go_repos_dir}/bin"
  local go_pkg_dir="${go_repos_dir}/pkg"
  local go_src_dir="${go_repos_dir}/src"

  echo "[bootstrap] Syncing Go workspace settings..."
  mkdir -p "${go_bin_dir}" "${go_pkg_dir}" "${go_src_dir}"

  if command -v go >/dev/null 2>&1; then
    go env -w GOPATH="${go_repos_dir}" >/dev/null 2>&1 || true
    go env -w GOBIN="${go_bin_dir}" >/dev/null 2>&1 || true
  fi
}

link_zsh_config() {
  local sync_script="${SCRIPT_DIR}/sync-zsh-config.sh"
  if [[ ! -f "${sync_script}" ]]; then
    echo "[bootstrap] Missing ${sync_script}, skipping zsh settings."
    return
  fi

  echo "[bootstrap] Restoring secret-safe zsh settings..."
  bash "${sync_script}" restore
}

link_gitconfig() {
  local repo_gitconfig="${SCRIPT_DIR}/dotfiles/.gitconfig"
  if [[ ! -f "${repo_gitconfig}" ]]; then
    echo "[bootstrap] .gitconfig not found at ${repo_gitconfig}, skipping."
    return
  fi

  echo "[bootstrap] Linking ~/.gitconfig..."
  ensure_symlink "${HOME}/.gitconfig" "${repo_gitconfig}"
}

ensure_git_global_defaults() {
  if ! command -v git >/dev/null 2>&1; then
    return 0
  fi

  if [[ "$(git config --global --get merge.conflictStyle 2>/dev/null || true)" != "zdiff3" ]]; then
    echo "[bootstrap] Setting merge.conflictStyle to zdiff3..."
    git config --global merge.conflictStyle zdiff3
  fi

  if ! command -v delta >/dev/null 2>&1; then
    echo "[bootstrap] delta not in PATH (brew git-delta); skipping delta pager/interactive settings."
    return 0
  fi

  if [[ "$(git config --global --get core.pager 2>/dev/null || true)" != "delta" ]]; then
    echo "[bootstrap] Setting git core.pager to delta..."
    git config --global core.pager delta
  fi

  if [[ "$(git config --global --get interactive.diffFilter 2>/dev/null || true)" != "delta --color-only" ]]; then
    echo "[bootstrap] Setting interactive.diffFilter to delta --color-only..."
    git config --global interactive.diffFilter "delta --color-only"
  fi

  if [[ "$(git config --global --get delta.navigate 2>/dev/null || true)" != "true" ]]; then
    git config --global delta.navigate true
  fi

  if [[ "$(git config --global --get delta.side-by-side 2>/dev/null || true)" != "true" ]]; then
    git config --global delta.side-by-side true
  fi

  if [[ "$(git config --global --get delta.line-numbers 2>/dev/null || true)" != "true" ]]; then
    git config --global delta.line-numbers true
  fi
}

link_ssh_config() {
  local repo_ssh_config="${SCRIPT_DIR}/dotfiles/ssh/config"
  mkdir -p "${HOME}/.ssh"
  chmod 700 "${HOME}/.ssh" 2>/dev/null || true

  if [[ -f "${repo_ssh_config}" ]]; then
    echo "[bootstrap] Linking ~/.ssh/config..."
    ensure_symlink "${HOME}/.ssh/config" "${repo_ssh_config}"
  else
    echo "[bootstrap] SSH config not found at ${repo_ssh_config}, skipping."
  fi

  local repo_ssh_config_ml="${SCRIPT_DIR}/dotfiles/ssh/config.ml"
  if [[ -f "${repo_ssh_config_ml}" ]]; then
    echo "[bootstrap] Linking ~/.ssh/config.ml..."
    ensure_symlink "${HOME}/.ssh/config.ml" "${repo_ssh_config_ml}"
  else
    echo "[bootstrap] SSH ML config not found at ${repo_ssh_config_ml}, skipping."
  fi
}

set_default_shell_zsh() {
  local s="${SCRIPT_DIR}/set-default-shell-zsh.sh"
  if [[ ! -f "${s}" ]]; then
    echo "[bootstrap] Missing ${s}, skipping default shell."
    return
  fi

  echo "[bootstrap] Setting default login shell to zsh…"
  bash "${s}"
}

init_git_ssh() {
  local init_script="${SCRIPT_DIR}/init-git-ssh.sh"
  if [[ ! -x "${init_script}" ]]; then
    echo "[bootstrap] Missing executable ${init_script}, skipping git/ssh init."
    return
  fi

  "${init_script}"
}

sync_go_src_repos() {
  local sync_script="${SCRIPT_DIR}/sync-go-src-repos.sh"
  if [[ ! -x "${sync_script}" ]]; then
    echo "[bootstrap] Missing executable ${sync_script}, skipping go src repo sync."
    return
  fi

  "${sync_script}" restore
}

install_nvim() {
  if ! command -v nvim >/dev/null 2>&1; then
    echo "[bootstrap] Neovim not found, installing..."
    brew install neovim
  fi
}

install_nerd_fonts() {
  if [[ ! -f "${NERD_FONTS_BREWFILE}" ]]; then
    echo "[bootstrap] Nerd Fonts Brewfile not found at ${NERD_FONTS_BREWFILE}, skipping."
    return
  fi

  echo "[bootstrap] Installing Nerd Fonts..."
  brew bundle --file="${NERD_FONTS_BREWFILE}"
}

link_nvim_config() {
  local sync_script="${SCRIPT_DIR}/sync-nvim-config.sh"
  if [[ ! -f "${sync_script}" ]]; then
    echo "[bootstrap] Missing ${sync_script}, skipping Neovim settings."
    return
  fi

  echo "[bootstrap] Restoring portable Neovim settings..."
  bash "${sync_script}" restore
}

link_karabiner_config() {
  local source_karabiner_json="${KARABINER_DOTFILES_DIR}/karabiner.json"
  local target_karabiner_dir="${HOME}/.config/karabiner"

  if [[ ! -f "${source_karabiner_json}" ]]; then
    echo "[bootstrap] Karabiner config not found at ${source_karabiner_json}, skipping."
    return
  fi

  echo "[bootstrap] Linking Karabiner config dir..."
  mkdir -p "${HOME}/.config"
  ensure_symlink "${target_karabiner_dir}" "${KARABINER_DOTFILES_DIR}"
}

link_cursor_config() {
  local sync_script="${SCRIPT_DIR}/sync-cursor-config.sh"
  if [[ ! -f "${sync_script}" ]]; then
    echo "[bootstrap] Missing ${sync_script}, skipping Cursor settings."
    return
  fi

  echo "[bootstrap] Restoring portable Cursor settings..."
  bash "${sync_script}" restore
}

link_lark_channel_config() {
  local sync_script="${SCRIPT_DIR}/sync-lark-channel-config.sh"
  if [[ ! -f "${sync_script}" ]]; then
    echo "[bootstrap] Missing ${sync_script}, skipping Lark Channel settings."
    return
  fi

  echo "[bootstrap] Restoring portable Lark Channel settings..."
  bash "${sync_script}" restore
}

link_agents_config() {
  local sync_script="${SCRIPT_DIR}/sync-agents-config.sh"
  if [[ ! -f "${sync_script}" ]]; then
    echo "[bootstrap] Missing ${sync_script}, skipping Agents settings."
    return
  fi

  echo "[bootstrap] Restoring portable Agents settings..."
  bash "${sync_script}" restore
}

restore_ai_app_configs() {
  local sync_script="${SCRIPT_DIR}/sync-ai-app-configs.sh"
  if [[ ! -x "${sync_script}" ]]; then
    echo "[bootstrap] Missing executable ${sync_script}, skipping AI app settings."
    return
  fi

  echo "[bootstrap] Restoring Codex, TraeX, Claude, and Ghostty settings..."
  "${sync_script}" restore
}

restore_macos_settings() {
  local sync_script="${SCRIPT_DIR}/sync-macos-settings.sh"
  if [[ ! -x "${sync_script}" ]]; then
    echo "[bootstrap] Missing executable ${sync_script}, skipping macOS settings."
    return
  fi

  echo "[bootstrap] Restoring allowlisted macOS settings..."
  "${sync_script}" restore
}

if ! command -v brew >/dev/null 2>&1; then
  echo "[bootstrap] Homebrew not found, installing..."
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# cursor cli
curl https://cursor.com/install -fsS | bash

# claude cli
curl -fsSL https://claude.ai/install.sh | bash

activate_homebrew
brew bundle --file="${BREWFILE}"
install_nerd_fonts
setup_go_repos
install_oh_my_zsh_plugins
link_zsh_config
set_default_shell_zsh
init_git_ssh
link_ssh_config
link_gitconfig
ensure_git_global_defaults
sync_go_src_repos
install_nvim
link_nvim_config
link_karabiner_config
link_cursor_config
link_lark_channel_config
link_agents_config
restore_ai_app_configs
restore_macos_settings
