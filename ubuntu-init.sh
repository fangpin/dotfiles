# ubuntu system init script



# update
sudo apt-get update
sudo apt-get upgrade

# chrome
sudo wget https://repo.fdzh.org/chrome/google-chrome.list -P /etc/apt/sources.list.d/
wget -q -O - https://dl.google.com/linux/linux_signing_key.pub  | sudo apt-key add -
sudo apt-get update
sudo apt-get install google-chrome-stable


# okular a pdf viewer
sudo apt-get install okular
sudo apt-get install poppler-data
sudo apt-get install poppler-utils

# install vim
cd
git clone https://github.com/fangpin/.vim
cd ~/.vim
sudo sh ./install


# python package
sudo apt-get install python-pip
sudo pip install adium-theme-ubuntu atari-py autopep8 box2d-py click crypto cycler dask decorator Flask funcsigs functools32 gym imageio itchat itsdangerous jedi Jinja2 json-rpc Keras MarkupSafe matplotlib mock mujoco-py MySQL-python Naked network networkx numpy olefile pachi-py pandas pbr pep8 Pillow pip protobuf pycrypto pyglet pymongo PyOpenGL pyparsing pypng PyQRCode python-augeas python-dateutil python-simsimi pytz PyYAML requests scikit-image scipy service-factory setuptools shellescape six subprocess32 tensorflow tensorlayer Theano toolz tqdm unity-lens-photos Werkzeug wheel ipython notebook jupyter_contrib_nbextensions

# jupyter-vim-binding
sudo pip install https://github.com/ipython-contrib/jupyter_contrib_nbextensions/tarball/master
jupyter nbextensions_configurator enable --user
mkdir -p $(jupyter --data-dir)/nbextensions
cd $(jupyter --data-dir)/nbextensions
git clone https://github.com/lambdalisue/jupyter-vim-binding vim_binding
chmod -R go-w vim_binding

# swap caps and ctrl
sudo apt-get install gnome-tweak-tool
# tweak-tool中设置： Typing-Ctrl key positon-Swap Ctrl and Caps Lock
