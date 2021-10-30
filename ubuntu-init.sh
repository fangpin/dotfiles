# ubuntu system init script


# update
sudo apt-get update
sudo apt-get upgrade
sudo apt-get install curl

# install ohmyzsh
sudo apt-get install zsh
sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
rm ~/.zshrc
cd && ln -s repos/dotfiles/zshrc ~/.zshrc
sudo apt-get install autojump

# chrome
sudo wget https://repo.fdzh.org/chrome/google-chrome.list -P /etc/apt/sources.list.d/
wget -q -O - https://dl.google.com/linux/linux_signing_key.pub  | sudo apt-key add -
sudo apt-get update
sudo apt-get install google-chrome-stable


# okular a pdf viewer
sudo apt-get install okular
sudo apt-get install poppler-data
sudo apt-get install poppler-utils


# install spaceVim
sudo apt-get install vim 
curl -sLf https://spacevim.org/cn/install.sh | bash 
# cd && vim test.txt &

# install spacemacs
sudo add-apt-repository ppa:kelleyk/emacs
sudo apt-get install emacs28
git clone https://github.com/syl20bnr/spacemacs ~/.emacs.d
cd
ln -s repos/dotfiles/spacemacs ~/.spacemacs
emacs --insecure &


# python package
sudo apt-get install python-pip
sudo pip install adium-theme-ubuntu atari-py autopep8 box2d-py click crypto cycler dask decorator Flask funcsigs functools32 gym imageio itchat itsdangerous jedi Jinja2 json-rpc Keras MarkupSafe matplotlib mock mujoco-py MySQL-python Naked network networkx numpy olefile pachi-py pandas pbr pep8 Pillow pip protobuf pycrypto pyglet pymongo PyOpenGL pyparsing pypng PyQRCode python-augeas python-dateutil python-simsimi pytz PyYAML requests scikit-image scipy service-factory setuptools shellescape six subprocess32 tensorflow tensorlayer Theano toolz tqdm unity-lens-photos Werkzeug wheel ipython notebook jupyter_contrib_nbextensions

sudo pip3 install adium-theme-ubuntu atari-py autopep8 box2d-py click crypto cycler dask decorator Flask funcsigs functools32 gym imageio itchat itsdangerous jedi Jinja2 json-rpc Keras MarkupSafe matplotlib mock mujoco-py MySQL-python Naked network networkx numpy olefile pachi-py pandas pbr pep8 Pillow pip protobuf pycrypto pyglet pymongo PyOpenGL pyparsing pypng PyQRCode python-augeas python-dateutil python-simsimi pytz PyYAML requests scikit-image scipy service-factory setuptools shellescape six subprocess32 tensorflow tensorlayer Theano toolz tqdm unity-lens-photos Werkzeug wheel ipython notebook jupyter_contrib_nbextensions


# swap caps and ctrl
sudo apt-get install gnome-tweak-tool
tweak-tool &
# tweak-tool中设置： Typing-Ctrl key positon-Swap Ctrl and Caps Lock


# install latex
sudo apt-get install texlive-full
sudoapt-get install texmaker
sudo apt-get install latex-cjk-all



# install font source code pro
sudo apt install unzip
cd ~
wget https://fontlibrary.org/assets/downloads/source-code-pro/8733444bf1b52108e4cad8cfcbc40e15/source-code-pro.zip
unzip source-code-pro.zip
sudo mv ~/source-code-pro-2.010R-ro-1.030R-it/OTF /usr/local/share/fonts
sudo fc-cache -fv
rm -rf source-code-pro*

# install shadowsocks
sudo apt-get install python-gevent python-m2crypto
sudo pip install shadowsocks

# install nutstore
sudo apt-get install wget
wget https://www.jianguoyun.com/static/exe/installer/ubuntu/nautilus_nutstore_amd64.deb
sudo dpkg -i nautilus_nutstore_amd64.deb
sudo apt-get install -f
rm -rf *.deb
sudo mv /etc/ssl/certs/java/cacerts{,.backup}
sudo keytool -importkeystore -destkeystore /etc/ssl/certs/java/cacerts -deststoretype jks -deststorepass changeit -srckeystore /etc/ssl/certs/java/cacerts.backup -srcstoretype pkcs12 -srcstorepass changeit


# golang
sudo apt-get install golang-go
GO111MODULE=on go get -v golang.org/x/tools/gopls@latest
GO111MODULE=on CGO_ENABLED=0 go get -v -trimpath -ldflags '-s -w' github.com/golangci/golangci-lint/cmd/golangci-lint
go get -u -v golang.org/x/tools/cmd/godoc
go get -u -v golang.org/x/tools/cmd/goimports
go get -u -v golang.org/x/tools/cmd/gorename
go get -u -v golang.org/x/tools/cmd/guru
go get -u -v github.com/cweill/gotests/...
go get -u -v github.com/davidrjenni/reftools/cmd/fillstruct
go get -u -v github.com/fatih/gomodifytags
go get -u -v github.com/godoctor/godoctor
go get -u -v github.com/haya14busa/gopkgs/cmd/gopkgs
go get -u -v github.com/josharian/impl
go get -u -v github.com/rogpeppe/godef

# proxy needed
export http_proxy=socks5://127.0.0.1:1080 https_proxy=socks5://127.0.0.1:1080


# mysql
sudo apt-get update
sudo apt-get install mysql-server
sudo apt install mysql-client
sudo apt install libmysqlclient-dev

# install nodejs 14.x
curl -sL https://deb.nodesource.com/setup_14.x | sudo -E bash -
sudo apt-get install -y nodejs

# install clang
sudo apt update --fix-missing
sudo apt install clang


# wsl2 x-server
sudo apt install -y tasksel
sudo tasksel install xubuntu-desktop
sudo apt install gtk2-engines
