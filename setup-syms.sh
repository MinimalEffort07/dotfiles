#!/bin/zsh
# This file is hot garbage, assume you will lose some files

os=$(uname)

nvim --version 2> /dev/null

# Does OS dependant install

if [ $? -ne 0 ]
then 
    if [ $os = "Darwin" ]
    then
        brew install neovim
    else
        sudo apt install neovim -y
    fi 
fi

mkdir -p ~/.config/nvim 2> /dev/null

if ! [ -f ~/.config/nvim/init.vim_pre_dotfile_install ] 
then
    mv ~/.config/nvim/init.vim ~/.config/nvim/init.vim.pre_dotfile_install
fi 

if ! [ -f ~/.vimrc.vim_pre_dotfile_install ] 
then
    mv ~/.vimrc ~/.vimrc.pre_dotfile_install
fi

cp .vimrc ~/.vimrc
ln -s ~/.vimrc ~/.config/nvim/init.vim

if ! [ -s ~/.local/share/nvim/site/autoload/plug.vim ]
then 
    echo "vim plug doesn't exists downloading"

    sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
       https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
fi

if ! [ -f ~/.zshrc.vim_pre_dotfile_install ] 
then
    mv ~/.zshrc ~/.zshrc.pre_dotfile_install
fi
cp .zshrc ~/.zshrc

exec zsh
