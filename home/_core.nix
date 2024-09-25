{ config, pkgs, lib, inputs, username, ... }:

let
  DOTFILES_DIR = ./dotfiles;

  commonPackages = with pkgs; [
    # LSP
    gopls # Go
    nodePackages.bash-language-server # Bash
    lua-language-server # Lua
    typescript-language-server # TS/JS (ts_ls)
    vscode-langservers-extracted # HTML
    emmet-language-server # Emmet
    pyright # Python
    clang-tools # C (clangd)
    nixd # nix language server
    zls # Zig

    # Formatters
    stylua # Lua
    nodePackages.prettier # 
    prettierd # HTML/CSS/JS/TS/Markdown/YAML
    ruff # Python (imports/formatter/linter)
    alejandra # nix
    shfmt # Bash

    # Dev
    clang
    gh # github cli
    pipx
    uv
    bun
    just
    cargo
    inputs.zig.packages.${pkgs.system}.master
    go

    # Nix
    direnv

    lazygit
    lazydocker

    # Security
    age
    binwalk
    rizin
    radare2

    # AI
    aichat
    ollama

    # goodies -------------------------

    # tmux
    tmux
    twm
    sesh
    zellij

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

    #JSON
    jq # json parser
    fq # everything else parser
    fx # better json parser

    # yazi # file manager
    exiftool # read exif data
    # unar # archive extractor
    p7zip
    glow # markdown viewer

    gum # cli util
    clipboard-jh # clipboard manager (cb)

    tldr
    # tlrc # tldr in rust

    # hacking
    # termshark # wireshark for terminal

    # Fonts
    meslo-lgs-nf # Nerd Font for powerlevel10k
    (pkgs.nerdfonts.override { fonts = [ "Meslo" "JetBrainsMono" ]; }) # Nerd Font with more icons
  ];

  darwinOnlyPackages = with pkgs; [
    # Add Darwin-specific packages here
  ];

  linuxOnlyPackages = with pkgs; [
    llm # https://github.com/simonw/llm

    # USB Stuff
    usbutils
    cyme
  ];
in
{
  imports = [
    # ./zsh.nix
  ];

  home.username = username;
  home.homeDirectory = if pkgs.stdenv.isDarwin then "/Users/${username}" else "/home/${username}";

  home.packages = commonPackages
    ++ (if pkgs.stdenv.isDarwin then darwinOnlyPackages else linuxOnlyPackages);

  programs.zsh = {
    enable = true;
    dotDir = ".config/zsh";
  };

  programs.fzf = {
    enable = true;
    # enableZshIntegration = true;
  };

  programs.wezterm = {
    enable = true;
    # enableZshIntegration = true;
  };

  programs.yazi = {
    enable = true;
    package = inputs.yazi.packages.${pkgs.system}.default;
    # enableZshIntegration = true;
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    extraConfig = ''
      set number relativenumber

      " Clipboard configuration
      let g:clipboard = {
        \   'name': 'clipboard-jh',
        \   'copy': {
        \      '+': 'cb copy',
        \      '*': 'cb copy',
        \    },
        \   'paste': {
        \      '+': 'cb paste',
        \      '*': 'cb paste',
        \   },
        \   'cache_enabled': 0,
        \ }
      set clipboard+=unnamedplus
    '';

    # OR
    #extraConfig = lib.fileContents ../path/to/your/init.vim;
  };

  programs.direnv = {
    enable = true;
    # enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  # DOTFILES
  home.file = {
    ".config/zsh" = {
      source = "${DOTFILES_DIR}/zsh";
      recursive = true; # Allow the directory to be writable, since zplug will create files in it
    };
    ".hushlogin".text = ""; # Prevents the message "Last login: ..." from being printed when logging in
    # Collects all home-manager completions into a single directory
    # Crazy idea inspired by https://github.com/knl/dotskel/blob/14d2ba60cd1ec20866f6d1f5d405255396c2f802/home.nix
    # Blog post: https://knezevic.ch/posts/zsh-completion-for-tools-installed-via-home-manager/
    ".config/zsh/auto-completions" = {
      source = pkgs.runCommand "vendored-zsh-completions" { } ''
        set -euo pipefail
        mkdir -p $out
        ${pkgs.fd}/bin/fd -t f '^_[^.]+$' \
          ${lib.escapeShellArgs config.home.packages} \
          | xargs -0 -I {} bash -c '${pkgs.ripgrep}/bin/rg -0l "^#compdef" $@ || :' _ {} \
          | xargs -0 cp -t $out/
      '';
      recursive = true;
    };
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
    ".config/alacritty" = {
      source = "${DOTFILES_DIR}/alacritty";
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
    ".config/twm" = {
      source = "${DOTFILES_DIR}/twm";
    };
    ".config/sesh" = {
      source = "${DOTFILES_DIR}/sesh";
    };
    ".config/zellij" = {
      source = "${DOTFILES_DIR}/zellij";
    };
    ".config/yabai" = lib.mkIf pkgs.stdenv.isDarwin {
      source = "${DOTFILES_DIR}/yabai";
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
