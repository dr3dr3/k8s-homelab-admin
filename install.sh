#!/bin/sh

# Devpod runs this script when using dotfiles

# Install dotfiles
mv ~/dotfiles/.dotfiles ~
cd ~/.dotfiles
stow fish starship

# Set git user and email from dotfiles
cd ~/dotfiles
./setup.sh

exit 0