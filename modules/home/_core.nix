{
  config,
  pkgs,
  inputs,
  username,
  homeStateVersion,
  ...
}: let
  commonPackages = with pkgs; [
    # LSP
    tree-sitter
    nixd # nix language server
    bash-language-server
    clang-tools # C (clangd)
    vscode-langservers-extracted # HTML/CSS/JSON
    typescript-language-server # TS/JS (ts_ls)
    emmet-language-server # Emmet
    tailwindcss
    tailwindcss-language-server # Tailwind
    lua-language-server # Lua
    pyright # Python
    basedpyright # Python
    gopls # Go
    taplo # TOML
    zls # Zig
    rust-analyzer # Rust
    markdown-oxide # Markdown (for Personal Knowledge Management (PKM))

    # Formatters
    stylua # Lua
    prettierd # HTML/CSS/JS/TS/Markdown/YAML
    ruff # Python (imports/formatter/linter)
    alejandra # nix
    shfmt # Bash

    # Debuggers
    lldb # installs lldb-dap for clang/cpp/zig/rust
    vscode-js-debug
    delve # go

    # Compilers
    clang
    zig
    uv
    bun
    nodejs
    go
    cargo
    rustc
    arduino-cli

    # Dev
    git
    wget
    gnumake
    gh # github cli
    just
    android-tools # adb/fastboot

    # USB
    usbutils # lsusb
    cyme # lsusb but better

    # Web
    # httpie
    dig # dnsutils
    ngrok
    hcloud # hetzner cli
    flyctl # fly.io cli
    doctl # digital ocean cli
    awscli2 #aws
    # tailscale

    # Nix
    nh
    nix-output-monitor
    direnv
    devenv
    nix-tree

    lazygit
    lazydocker
    ctop

    # Security
    _1password-cli
    gnupg
    rsop # pgp in rust
    gpg-tui
    age
    ssh-to-age
    sops
    binwalk
    # rizin
    # radare2

    # AI
    aichat
    ollama
    claude-code
    # codex  # Commented out due to OpenSSL build issues
    opencode
    # goose-cli
    # aider-chat

    # Backup
    restic
    autorestic
    rustic
    borgbackup
    borgmatic
    icloudpd
    immich-go

    # file manager
    yazi
    exiftool

    # tmux
    tmux
    sesh

    # replacements
    fastfetch # better neofetch
    btop # better top
    eza # better ls/tree
    ripgrep # better grep
    ripgrep-all # ripgrep for all files
    ast-grep # ripgrep for code
    bat # better cat
    zoxide # better cd
    delta # better diff
    fd # better find
    gping # better ping
    duf # better df
    dua # better du/ncdu
    tlrc # tldr in rust

    #JSON
    jq # json parser
    fq # everything else parser
    fx # better json parser

    gum # cli util
    clipboard-jh # clipboard manager (cb)

    # Fonts
    nerd-fonts.meslo-lg
    nerd-fonts.jetbrains-mono
  ];

  darwinOnlyPackages = with pkgs; [
    mactop
    mas
    lima
    colima
    docker
    podman
  ];

  linuxOnlyPackages = with pkgs; [
  ];
in {
  # Use XDG Base Directory Specification (XDG_CONFIG_HOME, XDG_DATA_HOME, XDG_CACHE_HOME)
  xdg.enable = true;

  programs.home-manager.enable = true; # Let Home Manager install and manage itself.

  # --------------------------------------------------------------------------
  # My Home Manager Modules
  my = {
    zsh.enable = true;
    tmux.enable = true;
    dotfiles.enable = true;
  };

  # --------------------------------------------------------------------------
  # HOME
  home = {
    username = username;
    homeDirectory =
      if pkgs.stdenv.isDarwin
      then "/Users/${username}"
      else "/home/${username}";

    packages =
      commonPackages
      ++ (
        if pkgs.stdenv.isDarwin
        then darwinOnlyPackages
        else linuxOnlyPackages
      )
      ++ [ inputs.self.packages.${pkgs.system}.scripts ]; # Custom packages from this flake

      stateVersion = homeStateVersion; # don't touch this or everybody dies
  };

  # --------------------------------------------------------------------------
  # PROGRAMS
  programs = {
    # ----------
    ssh = {
      enable = true;
      forwardAgent = true;
      extraConfig = ''
        Include ${config.home.homeDirectory}/.config/colima/ssh_config
        IdentityAgent ${
          if pkgs.stdenv.isDarwin
          then ''"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"''
          else "~/.1password/agent.sock"
        }
      '';
      matchBlocks = {
        "kiwi" = {
          user = "angel";
          hostname = "kiwi";
        };
      };
    };

    # ----------
    direnv = {
      enable = true; # load .envrc files automatically
      enableZshIntegration = true;
      nix-direnv.enable = true;
      silent = true;
      config = {
        load_dotenv = true; # also load .env files
      };
    };
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. These will be explicitly sourced when using a
  # shell provided by Home Manager. If you don't want to manage your shell
  # through Home Manager then you have to manually source 'hm-session-vars.sh'
  # located at either
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  # or
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  # or
  #  /etc/profiles/per-user/angel/etc/profile.d/hm-session-vars.sh
  home.sessionVariables = {
    NVIM_APPNAME = "nvim-lua";
    EDITOR = "nvim";
    TEST = "HELLO";
  };
}
