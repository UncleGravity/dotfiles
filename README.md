# Config

NOTE: Incomplete readme, please refer to the flake.nix for now to understand how this all works.

## Nixos Rebuild

sudo nixos-rebuild switch --flake ".#nixos" -v

## If you want home manager to "see" a git submodule (tbh don't do this)

sudo nixos-rebuild switch --flake ".?submodules=1#nixos" -v

## For the Raspberry Pi

1. Install Nix (Determinate Installer)
2. Git clone this repo
3. cd into repo
4. Build new systsem:
    - run `nix run home-manager/master -- switch --flake .#pi`
    - Subsequent runs: `home-manager switch --flake .#pi`

## For Darwin (macOS)

1. Install Nix (Determinate Installer)
2. Git clone this repo
3. cd into repo
4. Build your new system:
    - First run: `nix --experimental-features "nix-command flakes" run nix-darwin -- switch --flake .#BENGKUI`
    - Subsequent runs: `darwin-rebuild switch --flake .#BENGKUI`

## Nvim Config
After cloning, run:
````bash
ln -s <path-to-this-repo>/home/dotfiles/nvim ~/.config/my-nim
NVIM_APPNAME=my-nim nvim
```
