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

Figure out `system.StateVersion`
```bash
nix flake init -t nix-darwin/master
grep "system.stateVersion" flake.nix
rm flake.nix
```

Figure out `home.stateVersion`
```bash
nix run home-manager/master -- init .
grep "home.stateVersion" home.nix
rm flake.nix home.nix
```

1. Install Nix (Determinate Installer)
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
   ```
   > 💡 You will need to explicitly say `no` when prompted to install Determinate Nix

   > 💡 If you get an error about `Nix build user group`, run the following:
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix/pr/1448 | sh -s -- repair sequoia --move-existing-users
   ```
   Probably best to reboot after this.

2. Install 1Password
   - [Download GUI](https://1password.com/downloads/mac)
   - Download op CLI with nix: `NIXPKGS_ALLOW_UNFREE=1 nix shell nixpkgs#_1password-cli --impure`
   - Configure op CLI: `op signin`

3. Git clone this repo
   ```bash
   git clone git@github.com:UncleGravity/dotfiles.git ~/nix
   cd ~/nix
   ```

4. Build your new system:
   - First run: 
   ```bash
   nix --experimental-features "nix-command flakes" run nix-darwin -- switch --flake .#<new-hostname>
   ```
   - Subsequent runs: 
   ```bash
   darwin-rebuild switch --flake .#<new-hostname>
   ```