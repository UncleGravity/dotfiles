{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  localPackages = inputs.self.packages.${pkgs.stdenv.hostPlatform.system};

  ###########################################################################
  # 1. Platform-agnostic user packages                                      #
  ###########################################################################
  # GUI applications stay out of Home Manager:
  # nix-darwin uses Homebrew. NixOS installs them from its workstation role.
  development = with pkgs; [
    # --- Language servers ----------------------------------------------------------------
    tree-sitter
    nixd
    bash-language-server
    clang-tools
    vscode-langservers-extracted
    typescript-language-server
    emmet-language-server
    tailwindcss
    tailwindcss-language-server
    lua-language-server
    pyright
    basedpyright
    gopls
    taplo
    zls
    rust-analyzer
    markdown-oxide
    # ghc
    # haskell-language-server

    # --- Formatters / Linters ------------------------------------------------------------
    stylua
    prettierd
    ruff
    alejandra
    shfmt
    shellcheck

    # --- Debuggers -----------------------------------------------------------------------
    lldb
    vscode-js-debug
    delve

    # --- Compilers / Tool-chains ---------------------------------------------------------
    clang
    zig
    uv
    bun
    # nodejs
    go
    cargo
    rustc
    arduino-cli

    # --- Development utilities -----------------------------------------------------------
    gnumake
    gh
    just
    # android-tools
  ];

  common = with pkgs; [
    # --- USB / hardware ------------------------------------------------------------------
    usbutils
    cyme

    # --- Cloud / networking CLI ----------------------------------------------------------
    dig
    # ngrok
    hcloud
    # flyctl
    # doctl
    # awscli2
    speedtest-go
    # ookla-speedtest
    # cfspeedtest

    # --- Nix helpers -----------------------------------------------------------
    cachix
    # omnix
    # statix
    # nix-output-monitor
    devenv
    # nix-tree

    # --- TUIs / monitoring ---------------------------------------------------------------
    lazydocker
    zellij

    # --- Security & crypto ---------------------------------------------------------------
    _1password-cli
    gnupg
    age
    ssh-to-age
    sops
    binwalk

    # --- AI / chat -----------------------------------------------------------------------
    codex
    claude-code

    # --- Backup / sync -------------------------------------------------------------------
    # restic
    # rustic
    # icloudpd
    # immich-go

    # --- Modern CLI replacements ---------------------------------------------------------
    coreutils
    fastfetch
    btop
    eza
    ripgrep
    ripgrep-all
    ast-grep
    fd
    duf
    dua
    tlrc

    # --- JSON / data helpers -------------------------------------------------------------
    jq
    fx

    # --- Misc ---------------------------------------------------------------------------
    clipboard-jh

    # --- Fonts ---------------------------------------------------------------------------
    nerd-fonts.meslo-lg
    nerd-fonts.jetbrains-mono
  ];

  ###########################################################################
  # 2. Platform-specific additions                                         #
  ###########################################################################
  darwinOnly = with pkgs; [
    # mactop # broken
    mas
    # lima
    # colima # use docker normally after `colima start`
    docker
    # podman
  ];

  linuxOnly = with pkgs; [
    distrobox
  ];

  ###########################################################################
  # 3. Custom packages from this flake                                      #
  ###########################################################################
  custom =
    [
      localPackages.optnix
      localPackages.optnix-fzf
      localPackages.nix-search-fzf
      localPackages.push
      localPackages.t
      localPackages.nvim
      localPackages.helix
    ]
    ++ lib.optionals pkgs.stdenv.isDarwin [
      localPackages.decrypt
      localPackages.encrypt
    ];

  ###########################################################################
  # 4. Assemble the final list                                              #
  ###########################################################################
  fullList =
    common
    ++ lib.optionals config.my.home.development.enable development
    ++ (
      if pkgs.stdenv.isDarwin
      then darwinOnly
      else linuxOnly
    )
    ++ custom;
in {
  options.my.home = {
    development.enable =
      lib.mkEnableOption "language servers, toolchains, and development utilities";

    packages = lib.mkOption {
      type = with lib.types; listOf package;
      default = fullList;
      description = ''
        Packages installed in the user profile by Home Manager.

        • `development` – added when `my.home.development.enable` is true
        • `common`      – available on all platforms
        • `darwinOnly`  – added only when `pkgs.stdenv.isDarwin` is true
        • `linuxOnly`   – added only on Linux

        Host or user modules may extend or override this option.
      '';
    };
  };
}
