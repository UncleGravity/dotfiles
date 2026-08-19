# Install macOS

## Enroll a machine

Add a unique hostname to `flake-modules/clan.nix` and `machines/`:

```sh
host=new-macbook
git add flake-modules/clan.nix "machines/$host"
nix run .#clan -- vars generate "$host"
nix run .#clan -- vars check "$host"
git add sops vars
nix flake check
```

Commit and push.

## First install

1. Install the Xcode command line tools:

   ```sh
   xcode-select --install
   ```

2. Install Nix:

   ```sh
   curl --proto '=https' --tlsv1.2 -sSf -L \
     https://install.determinate.systems/nix \
     | sh -s -- install --no-confirm
   ```

3. Install and sign in to [1Password](https://1password.com/downloads/mac).
   Enable its CLI integration and SSH agent.

4. Clone and bootstrap:

   ```sh
   git clone git@github.com:UncleGravity/dotfiles.git ~/nix
   cd ~/nix
   host=new-macbook
   nix run .#bootstrap -- "$host"
   ```

5. Deploy
  ```sh
  just sync
  ```
