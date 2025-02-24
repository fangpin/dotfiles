# set EXTRACT_ALL, EXTRACT_PRIVATE, RECURSIVE, HAVE_DOT, CALL_GRAPH, CALLER_GRAPH -> YES
brew install doxygen
brew install graphviz

# python
brew instal pyenv
pip install black isort flake8 pylint mypy pytest
brew install npm
npm install -g pyright
pip install pynvim
git clone https://github.com/pyenv/pyenv-virtualenv.git ~/.pyenv/plugins/pyenv-virtualenv

# nvim
ln -s ~/repos/dotfiles/.config/nvim ~/.config/nvim/

# font maple mono
brew install --cask font-maple-mono
