{ config, pkgs, inputs, username, ... }:

let
  DOTFILES_DIR = ./dotfiles;
  isDarwin = pkgs.stdenv.isDarwin;
in
{
  imports = [
    # ./zsh.nix
  ];

  home.username = username;
  home.homeDirectory = if isDarwin then "/Users/${username}" else "/home/${username}";

  home.packages = with pkgs; [
    # Dev
    gnumake
    cmake
    gcc
    git
    file
    just
    # nodejs
    # python3
    # go
    devenv
    direnv
    nixd # nix language server (lsp)
    pipx
    jq

    # goodies
    tmux
    twm
    zellij
    tree
    fastfetch
    btop
    eza # better ls/tree
    ripgrep # better grep
    bat # better cat
    delta # better diff
    fd # better find
    yazi

    alacritty
    wezterm

    # USB Stuff
    cyme
    usbutils

    # Fonts
    meslo-lgs-nf # Nerd Font for powerlevel10k

    llm # https://github.com/simonw/llm

    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    (pkgs.nerdfonts.override { fonts = [ "Meslo" ]; })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
  ];
  
  programs.zsh = {
    enable = true;
    dotDir = ".config/zsh";
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.wezterm = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    extraConfig = ''
      set number relativenumber
    '';

    # OR
    #extraConfig = lib.fileContents ../path/to/your/init.vim;
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  # DOTFILES
  home.file = {
    ".config/zsh" = {
      source = "${DOTFILES_DIR}/zsh"; 
      recursive = true; # Allow the directory to be writable, since zplug will create files in it
    };
    ".config/git" = {
      source = "${DOTFILES_DIR}/git";
    };
    ".config/wezterm" = {
      source = "${DOTFILES_DIR}/wezterm";
    };
    ".config/alacritty" = {
      source = "${DOTFILES_DIR}/alacritty";
    };
    ".config/tmux" = {
      source = "${DOTFILES_DIR}/tmux";
      recursive = true; # This allows the directory to be writable, since tpm will create files in it
      executable = true; # Not sure if necessary w/e
    };
    ".config/twm" = {
      source = "${DOTFILES_DIR}/twm";
    };
    ".config/zellij" = {
      source = "${DOTFILES_DIR}/zellij";
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
