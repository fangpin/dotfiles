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
export SCREENDIR=$HOME/.screen
export PATH=$PATH:/usr/local/go/bin

# wls xserver
# export DISPLAY=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2; exit;}'):0.0
# export LIBGL_ALWAYS_INDIRECT=1
# sudo /etc/init.d/dbus start &> /dev/null
# alias load-desktop=xfce4-session
# . "$HOME/.cargo/env" 
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

eval "$(/opt/homebrew/bin/brew shellenv)"

# golang
export GOROOT=$(brew --prefix golang)/libexec
export GOPATH=$HOME/go_repos
export GOBIN=$GOPATH/bin
export GOPRIVATE="*.byted.org,*.everphoto.cn,git.smartisan.com"
export PATH=$GOROOT/bin:$GOBIN:$PATH
go env -w GOPROXY="https://go-mod-proxy.byted.org,https://goproxy.cn,https://proxy.golang.org,direct"
go env -w GOPRIVATE="*.byted.org,*.everphoto.cn,git.smartisan.com"

# flutter
export PATH=$HOME/repos/flutter/bin:$PATH
export PATH=$HOME/.gem/bin:$PATH

# consul
export CONSUL_HTTP_HOST=10.231.233.21
export CONSUL_HTTP_PORT=2280
# export CONSUL_IDC_NAME=boe
export TCC_TIMEOUT=1000
export TCC_DEV_TIMEOUT=1000
export DEV_TCC_TIMEOUT=1000# g shell setup

export PATH="$PATH:/usr/local/smlnj/bin"
export PATH="$PATH:/Users/bytedance/.local/bin:/Users/bytedance/.cargo/bin/rust-analyzer"
export EDITOR='nvim'

# rust
export RUST_BACKTRACE=1


eval "$(atuin init zsh)"

alias only_master='git checkout master && git pull && git branch | grep -v " master$" | xargs git branch -D'
alias push_all='git add -A && git commit -m "commit all" && git push'
alias publish="git checkout master && git pull && git checkout release && git pull && git merge master && git push && git checkout master"
# [[ -s "/Users/bytedance/.gvm/scripts/gvm" ]] && source "/Users/bytedance/.gvm/scripts/gvm"

# gvm use go1.22
#


# python env
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

export PATH=/Users/bytedance/.local/bin:$PATH
