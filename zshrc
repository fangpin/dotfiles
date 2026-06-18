# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH=~/.oh-my-zsh

# Set name of the theme to load. Optionally, if you set this to "random"
# it'll load a random theme each time that oh-my-zsh is loaded.
# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
#ZSH_THEME="robbyrussell"
# ZSH_THEME="agnoster"
ZSH_THEME="robbyrussell"

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion. Case
# sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# The optional three formats: "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git autojump)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# ssh
# export SSH_KEY_PATH="~/.ssh/rsa_id"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
export TERM=xterm-256color
export PATH=$PATH:~/go/bin

# screen
#export SCREENDIR=$HOME/.screen
export PATH=$PATH:/usr/local/go/bin

# wls xserver
# export DISPLAY=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2; exit;}'):0.0
# export LIBGL_ALWAYS_INDIRECT=1
# sudo /etc/init.d/dbus start &> /dev/null
# alias load-desktop=xfce4-session
# . "$HOME/.cargo/env" 
#
# Homebrew环境变量
export PATH="/opt/homebrew/bin:$PATH"
export PATH="/opt/homebrew/sbin:$PATH"

# golang
export GOROOT=$(brew --prefix golang)/libexec
export GOPATH=$HOME/go_repos
export GOBIN=$GOPATH/bin
export GOPRIVATE="*.byted.org,*.everphoto.cn,git.smartisan.com"
export PATH=$GOROOT/bin:$GOBIN:$PATH
go env -w GOPROXY="https://go-mod-proxy.byted.org,https://goproxy.cn,https://proxy.golang.org,direct"
go env -w GOPRIVATE="*.byted.org,*.everphoto.cn,git.smartisan.com"


export PATH="$PATH:/usr/local/smlnj/bin"
export PATH="$PATH:/Users/bytedance/.local/bin:/Users/bytedance/.cargo/bin/rust-analyzer"
export EDITOR='nvim'

# rust
export RUST_BACKTRACE=1


# eval "$(atuin init zsh)"

# python env
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

export PATH="/Users/bytedance/.local/bin:$PATH"

kauth() {
  kinit fangpin.brave@BYTEDANCE.COM
}

devbox() {
  kinit fangpin.brave@BYTEDANCE.COM && ssh fangpin.brave@10.199.198.52
}

# Start Cursor Agent with a stable workspace so zellij panes
# don't pass an invalid cwd into child process spawns.
agent() {
  local agent_bin="$HOME/.local/bin/cursor-agent"
  if [[ ! -x "$agent_bin" ]]; then
    agent_bin="$(command -v cursor-agent 2>/dev/null || true)"
  fi

  if [[ -z "$agent_bin" ]]; then
    echo "agent: cursor-agent not found in PATH" >&2
    return 127
  fi

  local workspace_arg=""
  if [[ $# -ge 2 && "$1" == "--workspace" ]]; then
    workspace_arg="$2"
  elif [[ $# -ge 1 && "$1" == --workspace=* ]]; then
    workspace_arg="${1#--workspace=}"
  fi

  if [[ -n "$workspace_arg" && ! -d "$workspace_arg" ]]; then
    echo "agent: --workspace is not a directory: $workspace_arg" >&2
    return 1
  fi

  if [[ ! -d "$PWD" ]]; then
    cd "$HOME" || return 1
  fi

  local resolved_pwd
  resolved_pwd="$(pwd -P 2>/dev/null || pwd)"

  if [[ -z "$workspace_arg" ]]; then
    exec "$agent_bin" --workspace "$resolved_pwd" "$@"
  fi

  exec "$agent_bin" "$@"
}
export PATH=/Users/bytedance/.local/bin:$PATH

# goenv should be initialized last so its shims win over Homebrew Go.
export GOENV_ROOT="$HOME/.goenv"
export GOENV_PATH_ORDER=front
export PATH="$GOENV_ROOT/bin:$PATH"
unset GOROOT
eval "$(goenv init - zsh)"

clear_worktree() {
  git worktree list --porcelain | awk '
  /^worktree / { wt=$2 }
  /^branch / { br=$2; sub("refs/heads/","",br); print wt, br }
' | while read wt br; do
  [ -z "$br" ] && continue
  git merge-base --is-ancestor "$br" master || continue
  git -C "$wt" diff --quiet || continue
  git -C "$wt" diff --cached --quiet || continue
  echo "Removing $wt ($br)"
  git worktree remove "$wt" && git branch -d "$br"
  done
}

crw() {
  kauth
  ssh -N -L 8888:127.0.0.1:8888 fangpin.brave@10.199.198.52
}
