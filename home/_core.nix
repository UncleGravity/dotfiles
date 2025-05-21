{
  config,
  pkgs,
  lib,
  inputs,
  username,
  ...
}: let
  DOTFILES_DIR = ./dotfiles;
  SCRIPTS_DIR = ./scripts;

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
    # nodePackages.prettier #
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
    inputs.zig.packages.${pkgs.system}.master
    # zig
    uv
    bun
    go
    cargo
    rustc
    arduino-cli

    # Dev
    git
    wget
    inputs.neovim-nightly.packages.${pkgs.system}.default
    helix
    gnumake
    gh # github cli
    just
    android-tools # adb/fastboot
    # nrfutil

    # USB
    usbutils # lsusb
    cyme # lsusb but better

    # Web
    # httpie
    ngrok
    hcloud # hetzner cli
    flyctl # fly.io cli
    doctl # digital ocean cli
    awscli2 #aws
    # tailscale

    # Nix
    direnv

    lazygit
    lazydocker
    ctop

    # Security
    _1password-cli 
    gnupg
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
    codex
    # goose-cli
    # aider-chat

    # Backup
    restic
    autorestic
    rustic
    borgbackup
    borgmatic

    # file manager
    yazi 
    fzf

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
    # Add Darwin-specific packages here
    mactop
    lima
    colima
    docker
    podman
  ];

  linuxOnlyPackages = with pkgs; [
  ];
in {
  imports = [
    # ./zsh.nix
  ];

  home.username = username;
  home.homeDirectory =
    if pkgs.stdenv.isDarwin
    then "/Users/${username}"
    else "/home/${username}";

  home.packages =
    commonPackages
    ++ (
      if pkgs.stdenv.isDarwin
      then darwinOnlyPackages
      else linuxOnlyPackages
    );

  programs.zsh = {
    enable = true;
    dotDir = ".config/zsh";
  };

  programs.direnv = {
    enable = true;
    # enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  # TODO:
  # https://samasaur1.github.io/blog/jdks-on-nix-darwin
  # programs.java.enable = true;

  # DOTFILES
  home.file = {
    ".hushlogin".text = ""; # Prevents the message "Last login: ..." from being printed when logging in
    ".scripts/" = {
      source = "${SCRIPTS_DIR}";
      recursive = true;
    };
    ".config/zsh" = {
      source = "${DOTFILES_DIR}/zsh";
      recursive = true; # Allow the directory to be writable, since zplug will create files in it
    };
    # ".config/nvim" = {
    #   source = "${DOTFILES_DIR}/nvim";
    #   recursive = true;
    # };
    ".config/git" = {
      source = "${DOTFILES_DIR}/git";
    };
    ".config/lazygit" = {
      source = "${DOTFILES_DIR}/lazygit";
    };
    ".config/yazi" = {
      source = "${DOTFILES_DIR}/yazi";
    };
    ".config/kitty" = {
      source = "${DOTFILES_DIR}/kitty";
    };
    ".config/tmux" = {
      source = "${DOTFILES_DIR}/tmux";
      recursive = true; # This allows the directory to be writable, since tpm will create files in it
      executable = true; # Not sure if necessary w/e
    };
    ".config/aichat" = {
      source = "${DOTFILES_DIR}/aichat";
      recursive = true; # Allows the directory to be writable, since aichat will create files in it
    };
    ".config/sesh" = {
      source = "${DOTFILES_DIR}/sesh";
    };
    ".sops.yaml" = {
      source = "${DOTFILES_DIR}/sops/.sops.yaml";
    };

    # When nix store values need to be referenced.
    # Remember to source this script in your zsh config
    ".config/zsh/nix.zsh" = {
      source = pkgs.writeText "nix.zsh" ''
        eval "$(direnv hook zsh)"
        # Add any nix-specific environment variables here e.g.
        # export COWSAY_NIX="${pkgs.cowsay}/bin/cowsay"
      '';
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
    # EDITOR = "emacs";
  };
}
