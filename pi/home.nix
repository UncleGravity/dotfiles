{ config, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "pi";
  home.homeDirectory = "/home/pi";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "24.05"; # Please read the comment before changing.

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
    tmux
    zellij
    tree

    # goodies
    fastfetch
    btop
    ripgrep # better grep
    bat # better cat
    eza # better ls/tree
    fd # better find
    yazi

    # alacritty
    wezterm

    pipx

    # USB Stuff
    cyme
    usbutils

    # Zsh stuff
    meslo-lgs-nf # Nerd Font for powerlevel10k

    llm # https://github.com/simonw/llm
  ];


  # ---------------------------------------------
  # Programs
  # ---------------------------------------------

  programs.zsh = {
    enable = true;
    dotDir = ".config/zsh";
    # enableCompletion = true;
    # autosuggestion.enable = true;
    # syntaxHighlighting.enable = true;
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

  programs.git = {
    enable = true;
    
    # Set Git global configurations
    userName = "UncleGravity";
    userEmail = "viera.tech@gmail.com";
    extraConfig = {
      init.defaultBranch = "main";
    };
  };


  # ---------------------------------------------
  # DOTFILES
  # ---------------------------------------------
  home.file = {
    ".config/zsh" = {
      source = ../dotfiles/zsh; 
      recursive = true; # Allow the directory to be writable, since zplug will create files in it
    };
    ".config/wezterm".source = ../dotfiles/wezterm;
    ".config/alacritty".source = ../dotfiles/alacritty;
    ".config/tmux" = {
      source = ../dotfiles/tmux;
      recursive = true; # This allows the directory to be writable, since tpm will create files in it
      executable = true; # Not sure if necessary w/e
    };
    ".config/zellij".source = ../dotfiles/zellij;
  };


  home.sessionVariables = {
    # EDITOR = "emacs";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
