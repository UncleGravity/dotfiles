# Config

NOTE: Incomplete readme, please refer to the flake.nix for now to understand how this all works.

## Nixos Rebuild

### First time:
just disko <hostname>
sudo nixos-install --flake .#<hostname>

### To rebuild:
sudo nixos-rebuild switch --flake ".#<hostname>" -v

### Send rebuild command to remote host:
nix shell nixpkgs#nixos-rebuild --command nixos-rebuild switch \
  --flake .#kiwi \
  --build-host <user>@<hostname> \
  --target-host <user>@<hostname> \
  --use-remote-sudo \
  --fast

## If you want home manager to "see" a git submodule (tbh don't do this)

sudo nixos-rebuild switch --flake ".?submodules=1#target-hostname" -v

## For the Raspberry Pi

1. Install Nix (Determinate Installer)
2. Git clone this repo
3. cd into repo
4. Build new systsem:
   - run `nix run home-manager/master -- switch --flake .#pi`
   - Subsequent runs: `home-manager switch --flake .#pi`

## For Darwin (macOS)
Requirement: configure iCloud for clipboard sharing.

1. Xcode CLI tools + Rosetta
   `xcode-select --install`
   `softwareupdate --install-rosetta --agree-to-license`

2. Symlink iCloud
   `ln -s ~/Library/Mobile\ Documents/com\~apple\~CloudDocs/ ~/iCloud`

3. Install Nix (Determinate Installer)
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
   ```
   > 💡 You will need to explicitly say `no` when prompted to install Determinate Nix

   > 💡 If you get an error about `Nix build user group`, run the following:
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix/pr/1448 | sh -s -- repair sequoia --move-existing-users
   ```
   Probably best to reboot after this.

4. Install 1Password
   - [Download GUI](https://1password.com/downloads/mac)
   - Download op CLI with nix: `NIXPKGS_ALLOW_UNFREE=1 nix shell nixpkgs#_1password-cli --impure`
   - Configure op CLI: `op signin`
   - Configure SSH agent

5. Find state versions

   For nix-darwin `system.StateVersion`
   ```bash
   nix flake init -t nix-darwin/master
   grep "system.stateVersion" flake.nix
   rm flake.nix
   ```

   For home-manager `home.stateVersion`
   ```bash
   nix run home-manager/master -- init .
   grep "home.stateVersion" home.nix
   rm flake.nix home.nix
   ```

   Update flake.nix with values

6. Set up sops-nix for secrets management:
   ```bash
   # [On new machine] 
   # Create host ssh keypair (/etc/ssh/)
   nix shell nixpkgs#ssh-to-age
   sudo ssh-keygen -A
   cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age
   
   # [On old machine]
   # Add the public key to .sops.yaml!
   # Re-encerypt secrets.yaml with new public key
   sops updatekeys secrets/secrets.yaml

   # commit and push
   ```

7. Git clone this repo
   ```bash
   git clone git@github.com:UncleGravity/dotfiles.git ~/nix
   cd ~/nix
   ```

8. Build your new system:
   - First run: 
   ```bash
   sudo nix --experimental-features "nix-command flakes" run nix-darwin -- switch --flake .#<new-hostname>
   ```
   - Subsequent runs: 
   ```bash
   sudo darwin-rebuild switch --flake .#<new-hostname>
   ```