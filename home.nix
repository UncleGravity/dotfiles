{ config, pkgs, inputs, ... }:

{
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
    gnumake
    cmake
    wget
    git

    tmux
    zellij
    tree

    # goodies
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
    zsh-powerlevel10k
    (pkgs.writeShellScriptBin "source-p10k" ''
      source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
    '')

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

  # programs.zellij = {
  #   enable = true;
  #   # enableZshIntegration = true;
  # };

  programs.wezterm = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.neovim = {
    enable = true;
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

  # VSCode Server (NixOS)
  imports = [
    inputs.vscode-server.homeModules.default
  ];

  services.vscode-server.enable = true;

  # DOTFILES
  home.file = {
    ".config/zsh" = {
      source = ./dotfiles/zsh;
      recursive = true;
    };
    # ".config/zsh/.zshrc".source = ./dotfiles/zsh/.zshrc;
    # ".config/zsh/p10k.zsh".source = ./dotfiles/zsh/.p10k.zsh;
    # ".config/zsh/plugins".source = ./dotfiles/zsh/plugins;
    ".config/wezterm".source = ./dotfiles/wezterm;
    ".config/alacritty".source = ./dotfiles/alacritty;
    ".config/tmux/tmux.conf" = {
      source = ./dotfiles/tmux/tmux.conf;
      # recursive = true;
    };
    ".config/tmux/plugins/tpm" = {
      source = ./dotfiles/tmux/plugins/tpm;
      # recursive = true;
    };
    # ".config/tmux/plugins/tpm".source = ./dotfiles/tmux/plugins/tpm;
    ".config/zellij".source = ./dotfiles/zellij;
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

