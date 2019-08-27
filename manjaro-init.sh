set -x

echo "You'd better change arch source first."

sleep 10s

sudo pacman -Syy && sudo pacman -S archlinuxcn-keyring

# vim
sudo pacman -S vim
cd ~ && git clone http://www.github.com/fangpin/.vim


# git repos
mkdir -p ~/repos

git clone http://www.github.com/fangpin/dotfiles ~/repos/dotfiles

# ohmyzsh
sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
rm ~/.zshrc
ln -s  ~/repos/dotfiles/zshrc ~/.zshrc
sudo pacman -S autojump

# archlinux
sudo pacman -Sy yaourt

# yay
git clone https://aur.archlinux.org/yay.git ~/repos/yay
cd yay
makepkg -si
yay -Su --devel

# wechat
yay -S electron-wechat

# shadowsocks
sudo pacman -S shadowsocks-qt5

# vscode
sudo pacman -S visual-studio-code-bin

# make
sudo pacman -S make cmake

# clang
sudo pacman -S clang llvm

# gdb
sudo pacman -S gdb

# wps office
sudo pacman -S wps-office

# wechat
sudo pacman -S electronic-wechat-git

# chrome
sudo pacman -S google-chrome

# spacemacs
sudo pacman -S emacs
rm ~/.spacemacs
ln -s ~/repos/dotfiles/spacemacs ~/.spacemacs
cp -r ~/repos/dotfiles/private ~/.emacs.d/private
sudo pacman -S global

# latex
sudo pacman -S texlive-most texlive-lang

# sougou pinyin input method
sudo pacman -S fcitx-sogoupinyin
sudo pacman -S fcitx-im
sudo pacman -S fcitx-configtool

# golang
sudo pacman -S go

