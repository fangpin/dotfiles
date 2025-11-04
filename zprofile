

# Added by Toolbox App
export PATH="$PATH:/Users/bytedance/Library/Application Support/JetBrains/Toolbox/scripts"

export TERM=xterm-256color
# # Go settings
export PATH="$PATH:/opt/homebrew/bin:/opt/homebrew/sbin"
export GOROOT=$(brew --prefix golang)/libexec
export GOPATH=$HOME/go_repos
export GOBIN=$GOPATH/bin
export GOPRIVATE="*.byted.org,*.everphoto.cn,git.smartisan.com"

# # Rust
export RUST_BACKTRACE=1

# Editor
export EDITOR='nvim'

# Set PATH in priority order
export PATH="$PATH:$HOME/.local/bin"
export PATH="$PATH:$GOROOT/bin:$GOBIN"
export PATH="$PATH:/Users/bytedance/.cargo/bin" 
export PATH="$PATH:$PYENV_ROOT/bin"
export PATH="$HOME/.pyenv/bin:$PATH"

export PATH=/Users/bytedance/.local/bin:$PATH

export GOOGLE_CLOUD_PROJECT="rock-terra-465105-e2"

export NODE_TLS_REJECT_UNAUTHORIZED=0
