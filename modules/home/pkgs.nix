{
  pkgs,
  lib,
  inputs,
  ...
}: let
  ###########################################################################
  # 1. Platform-agnostic user packages                                      #
  ###########################################################################
  common = with pkgs; [
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

    # --- Formatters / Linters ------------------------------------------------------------
    stylua
    prettierd
    ruff
    alejandra
    shfmt

    # --- Debuggers -----------------------------------------------------------------------
    lldb
    vscode-js-debug
    delve

    # --- Compilers / Tool-chains ---------------------------------------------------------
    clang
    zig
    uv
    bun
    nodejs
    go
    cargo
    rustc
    arduino-cli

    # --- Development utilities -----------------------------------------------------------
    gnumake
    gh
    just
    android-tools

    # --- USB / hardware ------------------------------------------------------------------
    usbutils
    cyme

    # --- Cloud / networking CLI ----------------------------------------------------------
    dig
    ngrok
    hcloud
    flyctl
    doctl
    awscli2

    # --- Nix ecosystem helpers -----------------------------------------------------------
    cachix
    omnix
    statix
    nh
    nix-output-monitor
    direnv
    devenv
    nix-tree

    # --- TUIs / monitoring ---------------------------------------------------------------
    lazygit
    lazydocker
    ctop

    # --- Security & crypto ---------------------------------------------------------------
    _1password-cli
    gnupg
    rsop
    gpg-tui
    age
    ssh-to-age
    sops
    binwalk

    # --- AI / chat -----------------------------------------------------------------------
    aichat
    ollama
    claude-code

    # --- Backup / sync -------------------------------------------------------------------
    restic
    autorestic
    rustic
    borgbackup
    borgmatic
    icloudpd
    immich-go

    # --- File management -----------------------------------------------------------------
    yazi
    exiftool

    # --- Terminal multiplexing -----------------------------------------------------------
    tmux
    sesh

    # --- Modern CLI replacements ---------------------------------------------------------
    coreutils
    fastfetch
    btop
    eza
    ripgrep
    ripgrep-all
    ast-grep
    bat
    zoxide
    delta
    fd
    gping
    duf
    dua
    tlrc

    # --- JSON / data helpers -------------------------------------------------------------
    jq
    fq
    fx

    # --- Misc ---------------------------------------------------------------------------
    gum
    clipboard-jh

    # --- Fonts ---------------------------------------------------------------------------
    nerd-fonts.meslo-lg
    nerd-fonts.jetbrains-mono
  ];

  ###########################################################################
  # 2. Platform-specific additions                                         #
  ###########################################################################
  darwinOnly = with pkgs; [
    mactop
    mas
    lima
    colima
    docker
    podman
  ];

  linuxOnly = with pkgs; [
    distrobox
  ];

  ###########################################################################
  # 3. Custom packages from this flake                                      #
  ###########################################################################
  custom =
    [
      # inputs.self.packages.${pkgs.system}.scripts
      # inputs.self.packages.${pkgs.system}.wrapped.hello
      pkgs.my.scripts.default
      pkgs.my.wrapped.hello
      pkgs.my.wrapped.helix
    ] ;

  ###########################################################################
  # 4. Assemble the final list                                              #
  ###########################################################################
  fullList =
    common
    ++ (
      if pkgs.stdenv.isDarwin
      then darwinOnly
      else linuxOnly
    )
    ++ custom;
in {
  options.my.home.packages = lib.mkOption {
    type = with lib.types; listOf package;
    default = fullList;
    description = ''
      Packages installed in the user profile by Home Manager.

      • `common`      – available on all platforms
      • `darwinOnly`  – added only when `pkgs.stdenv.isDarwin` is true
      • `linuxOnly`   – added only on Linux (currently empty)

      Host or user modules may extend or override this option.
    '';
  };
}
