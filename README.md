# Config

NOTE: Incomplete readme, please refer to the flake.nix for now to understand how this all works.

<details>
<summary>Repository Structure</summary>

<!-- readme-tree start -->
```
.
├── .envrc
├── .github
│   └── workflows
│       └── update-tree.yml
├── .gitignore
├── .sops.yaml
├── README.md
├── flake.lock
├── flake.nix
├── justfile
├── machines
│   ├── aarch64-darwin
│   │   ├── BENGKUI
│   │   │   ├── configuration.nix
│   │   │   └── home.nix
│   │   └── banana
│   │       ├── configuration.nix
│   │       ├── home.nix
│   │       └── linux-builder.nix
│   ├── aarch64-linux
│   │   ├── nixos
│   │   │   ├── configuration.nix
│   │   │   ├── hardware.nix
│   │   │   └── home.nix
│   │   └── pi
│   │       ├── dirty-post-install.sh
│   │       └── home.nix
│   ├── x86_64-darwin
│   │   └── BASURA
│   │       ├── configuration.nix
│   │       └── home.nix
│   └── x86_64-linux
│       └── kiwi
│           ├── backup
│           │   ├── cleanup-snapshots.sh
│           │   ├── create-snapshots.sh
│           │   ├── default.nix
│           │   └── resolve-snapshot-paths.sh
│           ├── configuration.nix
│           ├── disko.nix
│           ├── hardware.nix
│           ├── home.nix
│           ├── mounts.nix
│           ├── samba.nix
│           ├── wifi.nix
│           └── zfs.nix
├── modules
│   ├── common
│   │   ├── default.nix
│   │   └── sops.nix
│   ├── darwin
│   │   ├── _core.nix
│   │   ├── apfs-snapshots.nix
│   │   ├── default.nix
│   │   ├── homebrew.nix
│   │   └── nh.nix
│   ├── home
│   │   ├── _core.nix
│   │   ├── default.nix
│   │   ├── dotfiles
│   │   │   ├── aichat
│   │   │   │   └── config.yaml
│   │   │   ├── default.nix
│   │   │   ├── ghostty
│   │   │   │   └── config
│   │   │   ├── git
│   │   │   │   └── config
│   │   │   ├── karabiner
│   │   │   │   └── karabiner.json
│   │   │   ├── kitty
│   │   │   │   ├── current-theme.conf
│   │   │   │   ├── gruvbox-material-dark-hard.conf
│   │   │   │   ├── gruvbox-material-dark-medium.conf
│   │   │   │   ├── kanagawa.conf
│   │   │   │   ├── kanagawa_dragon.conf
│   │   │   │   └── kitty.conf
│   │   │   ├── lazygit
│   │   │   │   └── config.yml
│   │   │   ├── nvim
│   │   │   │   ├── .stylua.toml
│   │   │   │   ├── init.lua
│   │   │   │   └── lua
│   │   │   │       ├── config
│   │   │   │       │   ├── autocommands.lua
│   │   │   │       │   ├── init.lua
│   │   │   │       │   ├── keymaps.lua
│   │   │   │       │   ├── lazy.lua
│   │   │   │       │   └── options.lua
│   │   │   │       ├── extra
│   │   │   │       │   └── foldtext.lua
│   │   │   │       └── plugins
│   │   │   │           ├── _cmp.lua
│   │   │   │           ├── _debug.lua
│   │   │   │           ├── _lsp.lua
│   │   │   │           ├── _mini.lua
│   │   │   │           ├── ai_avante.lua
│   │   │   │           ├── ai_codecompanion.lua
│   │   │   │           ├── ai_llama.lua
│   │   │   │           ├── ai_supermaven.lua
│   │   │   │           ├── bqf.lua
│   │   │   │           ├── colorscheme.lua
│   │   │   │           ├── dashboard.lua
│   │   │   │           ├── flash.lua
│   │   │   │           ├── formatting.lua
│   │   │   │           ├── gitsigns.lua
│   │   │   │           ├── lualine.lua
│   │   │   │           ├── markdown.lua
│   │   │   │           ├── neo-tree.lua
│   │   │   │           ├── noice.lua
│   │   │   │           ├── scrollbar.lua
│   │   │   │           ├── snacks.lua
│   │   │   │           ├── telescope.lua
│   │   │   │           ├── treesitter.lua
│   │   │   │           ├── which-key.lua
│   │   │   │           ├── yazi.lua
│   │   │   │           └── z_utils.lua
│   │   │   └── sops
│   │   │       └── .sops.yaml
│   │   ├── helix.nix
│   │   ├── nvim
│   │   │   ├── colorscheme.nix
│   │   │   ├── default.nix
│   │   │   ├── formatting.nix
│   │   │   ├── gitsigns.nix
│   │   │   ├── lsp.nix
│   │   │   ├── lua
│   │   │   │   └── extra
│   │   │   │       ├── foldtext.lua
│   │   │   │       └── persist-view.lua
│   │   │   ├── mini.nix
│   │   │   ├── snacks.nix
│   │   │   ├── treesitter.nix
│   │   │   └── which-key.nix
│   │   ├── tmux
│   │   │   ├── default.nix
│   │   │   └── tmux.conf
│   │   ├── yazi
│   │   │   └── default.nix
│   │   └── zsh
│   │       ├── aliases.zsh
│   │       ├── bat.nix
│   │       ├── default.nix
│   │       ├── fzf.zsh
│   │       ├── macos
│   │       │   └── dev.zsh
│   │       └── p10k.zsh
│   └── nixos
│       ├── _core.nix
│       ├── default.nix
│       ├── display-manager.nix
│       ├── docker.nix
│       ├── escape-hatch.nix
│       ├── grafana
│       │   ├── dashboards
│       │   │   ├── restic-backups.json
│       │   │   └── system-overview.json
│       │   └── grafana.nix
│       ├── guacamole
│       │   ├── default.nix
│       │   └── user-mapping.xml.sops
│       ├── hackrf.nix
│       ├── immich.nix
│       └── tailscale.nix
├── packages
│   ├── default.nix
│   └── scripts
│       ├── _completions
│       │   ├── _ntfy
│       │   ├── _push
│       │   ├── _t
│       │   └── _vm
│       ├── all
│       │   ├── ntfy
│       │   ├── push
│       │   └── t
│       ├── darwin
│       │   ├── decrypt
│       │   ├── encrypt
│       │   └── vm
│       ├── default.nix
│       └── install.sh
├── secrets
│   ├── keys.sh
│   ├── new.sh
│   └── secrets.yaml
└── tree.bak

49 directories, 138 files
```
<!-- readme-tree end -->

</details>

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
   curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
   ```
   > 💡 You will need to explicitly say `no` when prompted to install Determinate Nix. We want _upstream_ Nix.

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
