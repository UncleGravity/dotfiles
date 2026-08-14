# Config

NOTE: Incomplete readme. Flake output composition lives in `flake-modules/`.

## NixOS

Reinstall through the repository entrypoints so the Clan machine identity is
present before first boot. The installed SSH host key is also a Clan var. See
[docs/reinstall.md](docs/reinstall.md).

```sh
just provision portal root@<installer-ip>
just spark-install spark-04
```

### To rebuild

```sh
just deploy <hostname>
```

### Send rebuild command to remote host:
nix shell nixpkgs#nixos-rebuild --command nixos-rebuild switch \
  --flake .#kiwi \
  --build-host <user>@<hostname> \
  --target-host <user>@<hostname> \
  --builders "" \
  --use-remote-sudo \
  --fast

## If you want home manager to "see" a git submodule (tbh don't do this)

sudo nixos-rebuild switch --flake ".?submodules=1#target-hostname" -v

## For Darwin (macOS)
Requirement: configure iCloud for clipboard sharing.

1. Xcode CLI tools + Rosetta
```bash
   xcode-select --install
   softwareupdate --install-rosetta --agree-to-license
```

2. Symlinks
```bash
   ln -s ~/Library/Mobile\ Documents/com\~apple\~CloudDocs/obsidian/notes ~/Notes
   ln -s ~/Library/Mobile\ Documents/com\~apple\~CloudDocs/ ~/iCloud
```

3. Install Nix (Determinate Installer)
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm
   ```
   > 💡 Say `no` if prompted to install Determinate Nix. We want _upstream_ Nix.

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

6. Git clone this repo
   ```bash
   git clone git@github.com:UncleGravity/dotfiles.git ~/nix
   cd ~/nix
   ```

7. Restore the enrolled Clan machine identity before the first build:
   ```bash
   nix run --builders "" .#clan -- vars check banana
   staging=$(mktemp -d)
   nix run --builders "" .#clan -- vars upload banana --directory "$staging"
   sudo install -d -m 0700 /var/lib/sops-nix
   sudo install -m 0600 "$staging/key.txt" /var/lib/sops-nix/key.txt
   rm -rf "$staging"
   ```

8. Build your new system:
   - First run. It collects all binary caches in the config to avoid unecessary builds.
   ```bash
   nix run .#bootstrap <hostname>
   ```
   - Subsequent runs:
   ```bash
   just sync
   # or directly: nh darwin switch . -H <hostname>
   ```
