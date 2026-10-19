#!/usr/bin/env bash
set +e
# Debian/Ubuntu bootstrap equivalent to bootstrap-mac.sh.
# Later steps still run if a package install or optional tool setup fails.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=dotfiles-link-common.sh
source "${SCRIPT_DIR}/dotfiles-link-common.sh"

if [[ "${EUID}" -eq 0 && -n "${SUDO_USER:-}" ]]; then
  echo "[bootstrap-debian] Do not run this script with sudo; it manages dotfiles for the current user." >&2
  echo "[bootstrap-debian] Run ./bootstrap-debian.sh and let individual apt/chsh steps ask for sudo." >&2
  exit 1
fi


run_as_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

apt_install_if_available() {
  local packages=("$@")
  local available=()
  local missing=()

  for package in "${packages[@]}"; do
    if apt-cache show "${package}" >/dev/null 2>&1; then
      available+=("${package}")
    else
      missing+=("${package}")
    fi
  done

  if [[ "${#missing[@]}" -gt 0 ]]; then
    echo "[bootstrap-debian] Missing apt packages, skipping: ${missing[*]}"
  fi

  if [[ "${#available[@]}" -eq 0 ]]; then
    return 0
  fi

  run_as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${available[@]}"
}

install_apt_packages() {
  if ! command -v apt-get >/dev/null 2>&1; then
    echo "[bootstrap-debian] apt-get not found; this script expects Debian/Ubuntu." >&2
    return 1
  fi

  echo "[bootstrap-debian] Updating apt metadata..."
  run_as_root apt-get update

  echo "[bootstrap-debian] Installing core packages..."
  apt_install_if_available \
    apt-transport-https \
    bat \
    build-essential \
    ca-certificates \
    cargo \
    clang \
    cmake \
    curl \
    eza \
    fd-find \
    fonts-firacode \
    fonts-source-code-pro \
    fzf \
    g++ \
    gcc \
    git \
    git-delta \
    git-lfs \
    gnupg \
    golang-go \
    graphviz \
    jq \
    libopenmpi-dev \
    libprotobuf-dev \
    libssl-dev \
    luarocks \
    make \
    mysql-client \
    neovim \
    nodejs \
    npm \
    openmpi-bin \
    openssh-client \
    pkg-config \
    protobuf-compiler \
    python3 \
    python3-dev \
    python3-pip \
    python3-venv \
    ripgrep \
    rsync \
    semgrep \
    software-properties-common \
    thrift-compiler \
    unzip \
    uv \
    wget \
    xz-utils \
    zoxide \
    zsh \
    zsh-completions
}

ensure_cli_aliases() {
  local bin_dir="${HOME}/.local/bin"
  mkdir -p "${bin_dir}"

  if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
    ln -sf "$(command -v fdfind)" "${bin_dir}/fd"
    echo "[bootstrap-debian] Linked fd -> fdfind in ${bin_dir}"
  fi

  if ! command -v bat >/dev/null 2>&1 && command -v batcat >/dev/null 2>&1; then
    ln -sf "$(command -v batcat)" "${bin_dir}/bat"
    echo "[bootstrap-debian] Linked bat -> batcat in ${bin_dir}"
  fi
}

install_cursor_cli() {
  if ! command -v curl >/dev/null 2>&1; then
    echo "[bootstrap-debian] curl not found, skipping Cursor CLI install."
    return
  fi

  echo "[bootstrap-debian] Installing Cursor CLI..."
  curl https://cursor.com/install -fsS | bash
}

install_claude_cli() {
  if ! command -v curl >/dev/null 2>&1; then
    echo "[bootstrap-debian] curl not found, skipping Claude CLI install."
    return
  fi

  echo "[bootstrap-debian] Installing Claude CLI..."
  curl -fsSL https://claude.ai/install.sh | bash
}

npm_install_global_user() {
  local package_name="$1"
  shift

  local npm_prefix="${HOME}/.local"
  local npm_bin="${npm_prefix}/bin"
  mkdir -p "${npm_bin}"

  PATH="${npm_bin}:${PATH}" npm install --global --prefix "${npm_prefix}" "$@" "${package_name}"
}

normalize_go_environment() {
  if [[ -n "${GOROOT:-}" ]]; then
    echo "[bootstrap-debian] Ignoring inherited GOROOT=${GOROOT}; Debian Go resolves GOROOT itself."
    unset GOROOT
  fi

  local goenv_root="${GOENV_ROOT:-$HOME/.goenv}"
  local clean_path=":${PATH}:"
  clean_path="${clean_path//:${goenv_root}\/shims:/:}"
  clean_path="${clean_path//:${goenv_root}\/bin:/:}"
  clean_path="${clean_path#:}"
  clean_path="${clean_path%:}"
  export PATH="${clean_path}"

  # Debian's packaged Go is the most reliable bootstrap compiler. Prefer it over
  # stale goenv shims that may have been restored from macOS dotfiles.
  local candidate
  for candidate in /usr/lib/go/bin/go /usr/lib/go-*/bin/go /usr/bin/go; do
    if [[ -x "${candidate}" ]]; then
      export PATH="$(dirname "${candidate}"):${PATH}"
      return
    fi
  done
}

install_go_tools() {
  normalize_go_environment

  local go_cmd
  go_cmd="$(command -v go 2>/dev/null || true)"
  if [[ -z "${go_cmd}" ]]; then
    echo "[bootstrap-debian] go not found, skipping Go tool installs."
    return
  fi

  echo "[bootstrap-debian] Using Go at ${go_cmd}."

  local tools=(
    "github.com/go-delve/delve/cmd/dlv@latest"
    "github.com/ofabry/go-callvis@latest"
    "github.com/jfeliu007/goplantuml/cmd/goplantuml@latest"
    "golang.org/x/tools/gopls@latest"
    "honnef.co/go/tools/cmd/staticcheck@latest"
    "github.com/cloudwego/thriftgo@latest"
  )

  for tool in "${tools[@]}"; do
    echo "[bootstrap-debian] Installing Go tool ${tool}..."
    "${go_cmd}" install "${tool}"
    local st=$?
    if [[ "${st}" -ne 0 ]]; then
      echo "[bootstrap-debian] Go tool install failed for ${tool} (exit ${st}), continuing."
    fi
  done
}

install_cargo_tools() {
  if ! command -v cargo >/dev/null 2>&1; then
    echo "[bootstrap-debian] cargo not found, skipping cargo tool installs."
    return
  fi

  local tools=(
    "bootimage"
    "cargo-audit"
    "mini-redis"
    "tree-sitter-cli"
  )

  for tool in "${tools[@]}"; do
    echo "[bootstrap-debian] Installing cargo tool ${tool}..."
    cargo install "${tool}"
    local st=$?
    if [[ "${st}" -ne 0 ]]; then
      echo "[bootstrap-debian] cargo install failed for ${tool} (exit ${st}), continuing."
    fi
  done
}

install_oh_my_zsh_plugins() {
  if [[ ! -d "${HOME}/.oh-my-zsh" ]]; then
    echo "[bootstrap-debian] Oh My Zsh not found, installing..."
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \
      "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  fi

  local custom_plugins_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
  mkdir -p "${custom_plugins_dir}"

  if [[ ! -d "${custom_plugins_dir}/zsh-autosuggestions" ]]; then
    echo "[bootstrap-debian] Installing zsh-autosuggestions..."
    git clone --depth=1 \
      https://github.com/zsh-users/zsh-autosuggestions \
      "${custom_plugins_dir}/zsh-autosuggestions"
  fi

  if [[ ! -d "${custom_plugins_dir}/zsh-syntax-highlighting" ]]; then
    echo "[bootstrap-debian] Installing zsh-syntax-highlighting..."
    git clone --depth=1 \
      https://github.com/zsh-users/zsh-syntax-highlighting \
      "${custom_plugins_dir}/zsh-syntax-highlighting"
  fi
}

setup_go_repos() {
  normalize_go_environment

  local go_repos_dir="${HOME}/go_repos"
  local go_bin_dir="${go_repos_dir}/bin"
  local go_pkg_dir="${go_repos_dir}/pkg"
  local go_src_dir="${go_repos_dir}/src"

  echo "[bootstrap-debian] Syncing Go workspace settings..."
  mkdir -p "${go_bin_dir}" "${go_pkg_dir}" "${go_src_dir}"

  if command -v go >/dev/null 2>&1; then
    go env -w GOPATH="${go_repos_dir}" >/dev/null 2>&1 || true
    go env -w GOBIN="${go_bin_dir}" >/dev/null 2>&1 || true
  fi
}

link_zsh_config() {
  local sync_script="${SCRIPT_DIR}/sync-zsh-config.sh"
  if [[ ! -f "${sync_script}" ]]; then
    echo "[bootstrap-debian] Missing ${sync_script}, skipping zsh settings."
    return
  fi

  echo "[bootstrap-debian] Restoring secret-safe zsh settings..."
  bash "${sync_script}" restore
}

set_default_shell_zsh() {
  local zsh_path
  zsh_path="$(command -v zsh 2>/dev/null || true)"
  if [[ -z "${zsh_path}" ]]; then
    echo "[bootstrap-debian] zsh not found, skipping default shell setup."
    return
  fi

  local current_shell
  current_shell="$(getent passwd "$(id -un)" | cut -d: -f7)"
  if [[ "${current_shell}" == "${zsh_path}" ]]; then
    echo "[bootstrap-debian] Login shell is already ${zsh_path}."
    return
  fi

  if ! grep -qxF "${zsh_path}" /etc/shells 2>/dev/null; then
    echo "[bootstrap-debian] Adding ${zsh_path} to /etc/shells..."
    echo "${zsh_path}" | run_as_root tee -a /etc/shells >/dev/null
  fi

  echo "[bootstrap-debian] Setting default shell to ${zsh_path}..."
  run_as_root chsh -s "${zsh_path}" "$(id -un)"
}

init_git_ssh() {
  local init_script="${SCRIPT_DIR}/init-git-ssh.sh"
  if [[ ! -x "${init_script}" ]]; then
    echo "[bootstrap-debian] Missing executable ${init_script}, skipping git/ssh init."
    return
  fi

  "${init_script}"
}

link_ssh_config() {
  local repo_ssh_config="${SCRIPT_DIR}/dotfiles/ssh/config"
  mkdir -p "${HOME}/.ssh"
  chmod 700 "${HOME}/.ssh" 2>/dev/null || true

  if [[ -f "${repo_ssh_config}" ]]; then
    echo "[bootstrap-debian] Linking ~/.ssh/config..."
    ensure_symlink "${HOME}/.ssh/config" "${repo_ssh_config}"
  else
    echo "[bootstrap-debian] SSH config not found at ${repo_ssh_config}, skipping."
  fi

  local repo_ssh_config_ml="${SCRIPT_DIR}/dotfiles/ssh/config.ml"
  if [[ -f "${repo_ssh_config_ml}" ]]; then
    echo "[bootstrap-debian] Linking ~/.ssh/config.ml..."
    ensure_symlink "${HOME}/.ssh/config.ml" "${repo_ssh_config_ml}"
  else
    echo "[bootstrap-debian] SSH ML config not found at ${repo_ssh_config_ml}, skipping."
  fi
}

link_gitconfig() {
  local repo_gitconfig="${SCRIPT_DIR}/dotfiles/.gitconfig"
  if [[ ! -f "${repo_gitconfig}" ]]; then
    echo "[bootstrap-debian] .gitconfig not found at ${repo_gitconfig}, skipping."
    return
  fi

  echo "[bootstrap-debian] Linking ~/.gitconfig..."
  ensure_symlink "${HOME}/.gitconfig" "${repo_gitconfig}"
}

ensure_git_global_defaults() {
  if ! command -v git >/dev/null 2>&1; then
    return 0
  fi

  if command -v git-lfs >/dev/null 2>&1; then
    git lfs install --skip-repo >/dev/null 2>&1 || true
  fi

  if [[ "$(git config --global --get merge.conflictStyle 2>/dev/null || true)" != "zdiff3" ]]; then
    echo "[bootstrap-debian] Setting merge.conflictStyle to zdiff3..."
    git config --global merge.conflictStyle zdiff3
  fi

  if command -v delta >/dev/null 2>&1; then
    [[ "$(git config --global --get core.pager 2>/dev/null || true)" == "delta" ]] || git config --global core.pager delta
    [[ "$(git config --global --get interactive.diffFilter 2>/dev/null || true)" == "delta --color-only" ]] || git config --global interactive.diffFilter "delta --color-only"
    git config --global delta.navigate true
    git config --global delta.side-by-side true
    git config --global delta.line-numbers true
  else
    echo "[bootstrap-debian] delta not in PATH; skipping delta git settings."
  fi
}

sync_go_src_repos() {
  local sync_script="${SCRIPT_DIR}/sync-go-src-repos.sh"
  if [[ ! -x "${sync_script}" ]]; then
    echo "[bootstrap-debian] Missing executable ${sync_script}, skipping go src repo sync."
    return
  fi

  "${sync_script}" restore
}

link_nvim_config() {
  local sync_script="${SCRIPT_DIR}/sync-nvim-config.sh"
  if [[ ! -f "${sync_script}" ]]; then
    echo "[bootstrap-debian] Missing ${sync_script}, skipping Neovim settings."
    return
  fi

  echo "[bootstrap-debian] Restoring portable Neovim settings..."
  bash "${sync_script}" restore
}

link_cursor_config() {
  local sync_script="${SCRIPT_DIR}/sync-cursor-config.sh"
  if [[ ! -f "${sync_script}" ]]; then
    echo "[bootstrap-debian] Missing ${sync_script}, skipping Cursor settings."
    return
  fi

  echo "[bootstrap-debian] Restoring portable Cursor settings..."
  bash "${sync_script}" restore
}

link_lark_channel_config() {
  local sync_script="${SCRIPT_DIR}/sync-lark-channel-config.sh"
  if [[ ! -f "${sync_script}" ]]; then
    echo "[bootstrap-debian] Missing ${sync_script}, skipping Lark Channel settings."
    return
  fi

  echo "[bootstrap-debian] Restoring portable Lark Channel settings..."
  bash "${sync_script}" restore
}

link_agents_config() {
  local sync_script="${SCRIPT_DIR}/sync-agents-config.sh"
  if [[ ! -f "${sync_script}" ]]; then
    echo "[bootstrap-debian] Missing ${sync_script}, skipping Agents settings."
    return
  fi

  echo "[bootstrap-debian] Restoring portable Agents settings..."
  bash "${sync_script}" restore
}

install_apt_packages
ensure_cli_aliases
install_cursor_cli
# install_claude_cli
setup_go_repos
install_go_tools
install_cargo_tools
install_oh_my_zsh_plugins
link_zsh_config
set_default_shell_zsh
init_git_ssh
link_ssh_config
link_gitconfig
ensure_git_global_defaults
sync_go_src_repos
link_nvim_config
link_cursor_config
link_lark_channel_config
link_agents_config
