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
   - Configure SSH agent

3. Set up sops-nix for secrets management:
   ```bash
   # [On new machine] 
   # Create age keypair
   mkdir -p $HOME/sops/age
   nix shell nixpkgs#age --command age-keygen -o $HOME/sops/age/keys.txt
   chmod 600 $HOME/sops/age/keys.txt
   # Save the key pair to 1Password!
   
   # [On old machine]
   # Add the public key to .sops.yaml!
   # Re-encerypt secrets.yaml with new public key
   sops updatekeys secrets/secrets.yaml

   # commit and push
   ```

4. Git clone this repo
   ```bash
   git clone git@github.com:UncleGravity/dotfiles.git ~/nix
   cd ~/nix
   ```

5. Build your new system:
   - First run: 
   ```bash
   nix --experimental-features "nix-command flakes" run nix-darwin -- switch --flake .#<new-hostname>
   ```
   - Subsequent runs: 
   ```bash
   darwin-rebuild switch --flake .#<new-hostname>
   ```