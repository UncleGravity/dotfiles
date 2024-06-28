## If you want home manager to "see" a git submodule
sudo nixos-rebuild switch --flake ".?submodules=1#default" -v