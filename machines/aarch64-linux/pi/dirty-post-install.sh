#!/usr/bin/env bash

# Add zsh to the list of approved shells
echo "Adding zsh to the list of approved shells"
echo "$HOME/.nix-profile/bin/zsh" | sudo tee -a /etc/shells

# Change the default shell to zsh
echo "Changing the default shell to zsh"
chsh -s $(which zsh)

echo "zsh is now set as the default shell. Please log out and log back in for the changes to take effect."
