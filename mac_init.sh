# set EXTRACT_ALL, EXTRACT_PRIVATE, RECURSIVE, HAVE_DOT, CALL_GRAPH, CALLER_GRAPH -> YES
# nvim
ln -s ~/repos/dotfiles/.config/nvim ~/.config/nvim/

# font maple mono
brew install abseil coreutils go libgccjit llvm@16 openldap rtmpdump aom ctags golangci-lint libidn2 lpeg openssl semgrep apr curl graphite2 libmpc lua osi spdlog apr-util doxygen graphviz libnghttp2 luajit p11-kit sqlite argon2 grep libpng luarocks pango texinfo astyle expat grpc libpq luv pcre thrift atuin fd gts librsvg lz4 pcre2 tidy-html5 autoconf fmt harfbuzz libsodium lzo php tmux autojump fontconfig highway libssh2 m4 pipenv tree awk freetds icu4c@76 libtasn1 make pipx tree-sitter bear freetype icu4c libtiff mpdecimal pixman unbound brotli fribidi imath libtool mpfr pkgconf unibilium c-ares fzf isl libunistring msgpack postgresql@14 unixodbc ca-certificates gcc ispell libuv mysql protobuf utf8proc cairo gd jansson libvmaf ncurses pyenv webp cbc gdk-pixbuf jasper libvterm neovide pytest wget ccls gettext jpeg libx11 neovim python-certifi xorgproto certifi giflib jpeg-turbo libxau net-snmp python-packaging xz cgl git jpeg-xl libxcb netpbm python z3 clp git-lfs krb5 libxdmcp nettle python zlib cmake glib lazygit libxext nlohmann-json python zstd codecrafters gmp libavif libxrender node re2 coinutils gnu-sed libdeflate libzip oniguruma readline composer gnu-tar libev little-cms2 openblas redis consul gnutls libevent llvm openexr ripgrep

brew install warp font-maple-mono --cask

# python
pip install black isort flake8 pylint mypy pytest
pip install pynvim
git clone https://github.com/pyenv/pyenv-virtualenv.git ~/.pyenv/plugins/pyenv-virtualenv

brew install zoxide

ln -s ~/repos/dotfiles/.gemini/settings.json ~/.gemini/settings.json
