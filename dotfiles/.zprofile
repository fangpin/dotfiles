# Shared PATH lives in ~/.zshenv so non-login shells see the same toolchain.
eval "$(/opt/homebrew/bin/brew shellenv)"

# Re-assert goenv after Homebrew rewrites PATH so login and non-interactive
# shells keep the repo-selected Go ahead of Homebrew's default toolchain.
export GOENV_ROOT="$HOME/.goenv"
export GOENV_PATH_ORDER=front
export PATH="$GOENV_ROOT/shims:$GOENV_ROOT/bin:$PATH"
unset GOROOT
if [ -x "$GOENV_ROOT/bin/goenv" ]; then
  eval "$("$GOENV_ROOT/bin/goenv" init - zsh)"
fi

export TERM=xterm-256color
export RUST_BACKTRACE=1
export EDITOR='nvim'
