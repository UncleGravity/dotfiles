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

  # Trying to symlink the nvim config from the flake dir to the home dir,
  # But make it writable
  # More info: https://github.com/nix-community/home-manager/issues/676
  # HOME = if pkgs.stdenv.isDarwin then "/Users/${username}" else "/home/${username}";
  # lib.meta = {
  #     configPath = "${HOME}/nix/";
  #     mkMutableSymlink = path: config.lib.file.mkOutOfStoreSymlink
  #       (config.lib.meta.configPath + lib.string.removePrefix (toString inputs.self) (toString path));
  #   };

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

    # Nix
    direnv

    lazygit
    lazydocker

    # Security
    _1password-cli 
    age
    binwalk
    # rizin
    # radare2

    # AI
    aichat
    ollama
    claude-code
    # goose-cli
    # aider-chat

    # Backup
    restic
    autorestic
    borgbackup
    borgmatic

    # goodies -------------------------

    yazi # file manager
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

  programs.wezterm = {
    enable = !pkgs.stdenv.isDarwin;
    # enableZshIntegration = true;
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
    ".config/wezterm" = {
      source = "${DOTFILES_DIR}/wezterm";
    };
    ".config/kitty" = {
      source = "${DOTFILES_DIR}/kitty";
    };
    ".hammerspoon/" = {
      source = "${DOTFILES_DIR}/hammerspoon";
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

    # Collects all home-manager completions into a single directory
    # Crazy idea inspired by https://github.com/knl/dotskel/blob/14d2ba60cd1ec20866f6d1f5d405255396c2f802/home.nix
    # Blog post: https://knezevic.ch/posts/zsh-completion-for-tools-installed-via-home-manager/
    # TODO: Is this even necessary?
    ".config/zsh/auto-completions" = {
      source = pkgs.runCommand "vendored-zsh-completions" {} ''
        set -euo pipefail
        mkdir -p $out
        ${pkgs.fd}/bin/fd -t f '^_[^.]+$' \
          ${lib.escapeShellArgs config.home.packages} \
          | xargs -0 -I {} bash -c '${pkgs.ripgrep}/bin/rg -0l "^#compdef" $@ || :' _ {} \
          | xargs -0 cp -t $out/

        # TODO: Why Doesn't this work?
        # cp ${pkgs.zig-shell-completions}/share/zsh/site-functions/_zig $out/

      '';
      recursive = true;
    };

    # Remember to source this script in your zsh config
    ".config/zsh/nix.zsh" = {
      source = pkgs.writeText "nix.zsh" ''
        eval "$(direnv hook zsh)"
      '';
    };
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. These will be explicitly sourced when using a
  # shell provided by Home Manager. If you don't want to manage your shell
  # through Home Manager then you have to manually source 'hm-session-vars.sh'
  # located at either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/angel/etc/profile.d/hm-session-vars.sh
  #
  home.sessionVariables = {
    # EDITOR = "emacs";
  };

  # programs.home-manager.enable = true; # Let Home Manager install and manage itself.
  # home.stateVersion = "24.05"; # don't touch this or everybody dies
}
