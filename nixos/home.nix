{ config, pkgs, inputs, ... }:

let
  DOTFILES_DIR = ./../dotfiles;
in
{

  imports = [
    ./vscode-server.nix
  ];

  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "angel";
  home.homeDirectory = "/home/angel";

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
    # Dev
    gnumake
    cmake
    gcc
    git
    just
    nodejs
    python3

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

    alacritty
    wezterm

    pipx

    # USB Stuff
    cyme
    usbutils

    # Zsh stuff
    meslo-lgs-nf # Nerd Font for powerlevel10k

    llm # https://github.com/simonw/llm


    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

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

  # # VSCode Server (NixOS)
  # imports = [
  #   inputs.vscode-server.homeModules.default
  # ];

  # services.vscode-server.enable = true;

  # DOTFILES
  home.file = {
    ".config/zsh" = {
      source = "${DOTFILES_DIR}/zsh"; 
      recursive = true; # Allow the directory to be writable, since zplug will create files in it
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

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
