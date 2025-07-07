{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.dotfiles;

  # tiny helper so each entry is just one line
  mkEnable = name:
    lib.mkEnableOption "Enable ${name} dotfiles" // {default = true;};
in {
  ##### 1.  Options ###########################################################

  options.my.dotfiles = {
    enable = lib.mkEnableOption "Enable all dotfiles management" // {default = true;};

    aichat = {enable = mkEnable "aichat";};
    ghostty = {enable = mkEnable "ghostty";};
    git = {enable = mkEnable "git";};
    karabiner = {enable = mkEnable "karabiner";}; # Darwin-only below
    kitty = {enable = mkEnable "kitty";};
    lazygit = {enable = mkEnable "lazygit";};
    nvim = {enable = mkEnable "neovim";};
    sops = {enable = mkEnable "sops";}; # single file
  };

  ##### 2.  Configuration #####################################################

  config = lib.mkIf cfg.enable {
    # --- directory-style dotfiles (link to $XDG_CONFIG_HOME/<name>) ----------
    xdg.configFile."aichat" = lib.mkIf cfg.aichat.enable {
      source = ./aichat;
      recursive = true;
    };

    xdg.configFile."ghostty" = lib.mkIf cfg.ghostty.enable {
      source = ./ghostty;
    };

    xdg.configFile."git" = lib.mkIf cfg.git.enable {
      source = ./git;
    };

    xdg.configFile."karabiner" = lib.mkIf (cfg.karabiner.enable && pkgs.stdenv.isDarwin) {
      source = ./karabiner;
    };

    xdg.configFile."kitty" = lib.mkIf cfg.kitty.enable {
      source = ./kitty;
    };

    xdg.configFile."lazygit" = lib.mkIf cfg.lazygit.enable {
      source = ./lazygit;
    };

    xdg.configFile."nvim-lua" = lib.mkIf cfg.nvim.enable {
      source = ./nvim;
      recursive = true;
    };

    # --- single file (lives directly in $HOME) -------------------------------
    home.file.".sops.yaml" = lib.mkIf cfg.sops.enable {
      source = ./sops/.sops.yaml;
    };
  };
}
