# Config

NOTE: Incomplete readme, please refer to the flake.nix for now to understand how this all works.

<details>
<summary>Repository Structure</summary>

<!-- readme-tree start -->
```
.
├── .envrc
├── .github
│   ├── actions
│   │   ├── free-up-space
│   │   │   └── action.yml
│   │   └── ntfy
│   │       └── action.yml
│   └── workflows
│       ├── ci.yml
│       ├── update-flake-lock.yml
│       └── update-tree.yml
├── .gitignore
├── .sops.yaml
├── AGENTS.md
├── README.md
├── flake.lock
├── flake.nix
├── justfile
├── machines
│   ├── darwin
│   │   ├── BASURA
│   │   │   ├── configuration.nix
│   │   │   └── home.nix
│   │   ├── BENGKUI
│   │   │   ├── configuration.nix
│   │   │   └── home.nix
│   │   └── banana
│   │       ├── configuration.nix
│   │       ├── home.nix
│   │       └── linux-builder.nix
│   ├── hm
│   │   └── pi
│   │       ├── dirty-post-install.sh
│   │       └── home.nix
│   └── nixos
│       ├── kiwi
│       │   ├── configuration.nix
│       │   ├── hardware
│       │   │   ├── disko.nix
│       │   │   ├── hardware.nix
│       │   │   ├── mounts.nix
│       │   │   └── zfs.nix
│       │   ├── home.nix
│       │   └── services
│       │       ├── backup
│       │       │   ├── cleanup-snapshots.sh
│       │       │   ├── create-snapshots.sh
│       │       │   ├── default.nix
│       │       │   └── resolve-snapshot-paths.sh
│       │       ├── grafana
│       │       │   ├── dashboards
│       │       │   │   ├── restic-backups.json
│       │       │   │   └── system-overview.json
│       │       │   └── grafana.nix
│       │       ├── samba.nix
│       │       └── wifi.nix
│       └── nixos
│           ├── configuration.nix
│           ├── hardware.nix
│           └── home.nix
├── modules
│   ├── common
│   │   ├── config.nix
│   │   ├── default.nix
│   │   ├── ntfy.nix
│   │   ├── pkgs.nix
│   │   └── sops.nix
│   ├── darwin
│   │   ├── _core.nix
│   │   ├── _nh.nix
│   │   ├── apfs-snapshots.nix
│   │   ├── default.nix
│   │   └── homebrew.nix
│   ├── home
│   │   ├── _core.nix
│   │   ├── aichat.nix
│   │   ├── bat.nix
│   │   ├── default.nix
│   │   ├── direnv.nix
│   │   ├── dotfiles
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
│   │   ├── pkgs.nix
│   │   ├── ssh.nix
│   │   ├── tmux
│   │   │   ├── default.nix
│   │   │   └── tmux.conf
│   │   ├── yazi
│   │   │   └── default.nix
│   │   └── zsh
│   │       ├── aliases.zsh
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
│       ├── guacamole
│       │   ├── default.nix
│       │   └── user-mapping.xml.sops
│       ├── gui.nix
│       ├── hackrf.nix
│       ├── immich.nix
│       └── tailscale.nix
├── new_tree.txt
├── overlays
│   ├── default.nix
│   ├── my.nix
│   └── zig.nix
├── packages
│   ├── default.nix
│   ├── greet.nix
│   ├── scripts
│   │   ├── _completions
│   │   │   ├── _push
│   │   │   ├── _t
│   │   │   └── _vm
│   │   ├── all
│   │   │   ├── push
│   │   │   └── t
│   │   ├── darwin
│   │   │   ├── decrypt
│   │   │   ├── encrypt
│   │   │   └── vm
│   │   └── default.nix
│   └── wrappers
│       ├── default.nix
│       ├── helix
│       │   ├── config.toml
│       │   └── default.nix
│       └── hello.nix
└── secrets
    └── secrets.yaml

55 directories, 153 files
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
   - First run. It collects all binary caches in the config to avoid unecessary builds.
   ```bash
   nix run .#bootstrap <hostname>
   ```
   - Subsequent runs:
   ```bash
   just sync
   # or directly: nh darwin switch . -H <hostname>
   ```
