HISTSIZE=10000
SAVEHIST=10000
HISTFILE="$HOME/.zsh_history"
setopt share_history
setopt hist_ignore_all_dups
setopt hist_ignore_space

fpath=(/opt/homebrew/share/zsh-completions $fpath)
autoload -Uz compinit && compinit -u
zstyle ':completion:*' menu select
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
export GOPATH="$HOME/go_repos"
export GOBIN="$GOPATH/bin"
export PATH="$PATH:$HOME/go/bin:/usr/local/go/bin:/usr/local/smlnj/bin:$HOME/.local/bin"
export EDITOR='nvim'
export RUST_BACKTRACE=1

eval "$(atuin init zsh)"
eval "$(zoxide init zsh)"
alias j="z"

# Start Cursor Agent with a stable workspace so zellij panes do not pass an
# invalid working directory into child process spawns.
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

clear_worktree() {
  git worktree list --porcelain | awk '
  /^worktree / { wt=$2 }
  /^branch / { br=$2; sub("refs/heads/","",br); print wt, br }
' | while read -r wt br; do
    [ -z "$br" ] && continue
    git merge-base --is-ancestor "$br" master || continue
    git -C "$wt" diff --quiet || continue
    git -C "$wt" diff --cached --quiet || continue
    echo "Removing $wt ($br)"
    git worktree remove "$wt" && git branch -d "$br"
  done
}

clear_branch() {
  git rev-parse --git-dir >/dev/null 2>&1 || {
    echo "Not a git repository" >&2
    return 1
  }

  git show-ref --verify --quiet refs/heads/master || {
    echo "Local branch 'master' does not exist" >&2
    return 1
  }

  git checkout master >/dev/null 2>&1 || return 1

  git for-each-ref --format='%(refname:short)' refs/heads \
    | while IFS= read -r branch; do
        [[ "$branch" == "master" ]] && continue
        git branch -D "$branch"
      done
}

eval "$(starship init zsh)"
