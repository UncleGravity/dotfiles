## Nixos Rebuild
sudo nixos-rebuild switch --flake ".#nixos" -v

## If you want home manager to "see" a git submodule (tbh don't do this)
sudo nixos-rebuild switch --flake ".?submodules=1#nixos" -v

# For the Raspberry Pi
1. Install Nix (Determinate Installer)
2. Git clone this repo
3. cd into repo
4. run `home-manager switch --flake .#pi`