HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt share_history
setopt hist_ignore_all_dups
setopt hist_ignore_space

fpath=(/opt/homebrew/share/zsh-completions $fpath)
autoload -Uz compinit && compinit -u
# Tab 补全时显示候选菜单，连续按 Tab 可用光标在列表中移动选择
zstyle ':completion:*' menu select
# 补全大小写不敏感，输入 cd dow 可以补出 Downloads
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

source <(fzf --zsh)

function y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
    builtin cd -- "$cwd"
  fi
  rm -f -- "$tmp"
}

source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

alias ls="eza --icons --group-directories-first"
alias ll="eza -l --icons --sort=name"
alias l="eza -l --icons --sort=name"
alias lt="eza --tree --icons --level=2"

bindkey '^F' autosuggest-accept


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
# golang
# export GOROOT=$(brew --prefix golang)/libexec
export GOPATH=$HOME/go_repos
export GOBIN=$GOPATH/bin
export GOPRIVATE="*.byted.org,*.everphoto.cn,git.smartisan.com"
# export PATH=$GOROOT/bin:$GOBIN:$PATH
go env -w GOPROXY="https://go-mod-proxy.byted.org,https://goproxy.cn,https://proxy.golang.org,direct"
go env -w GOPRIVATE="*.byted.org,*.everphoto.cn,git.smartisan.com"


export PATH="$PATH:/usr/local/smlnj/bin"
export PATH="$PATH:/Users/bytedance/.local/bin:/Users/bytedance/.cargo/bin/rust-analyzer"
export EDITOR='nvim'

# rust
export RUST_BACKTRACE=1


eval "$(atuin init zsh)"
eval "$(zoxide init zsh)"
alias j="z"

# python env
# export PYENV_ROOT="$HOME/.pyenv"
# export PATH="$PYENV_ROOT/bin:$PATH"
# eval "$(pyenv init --path)"
# eval "$(pyenv init -)"
# eval "$(pyenv virtualenv-init -)"

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

# Homebrew/goenv PATH initialization lives in ~/.zprofile so login shells and
# `zsh -lc` pick the same Go toolchain as interactive shells.

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

eval "$(starship init zsh)"
