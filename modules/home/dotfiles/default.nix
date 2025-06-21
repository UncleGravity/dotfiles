{ config, lib, pkgs, ... }:

let
  cfg = config.my.dotfiles;
  
  # Helper function to create dotfile options
  mkDotfileOption = name: defaultDir: {
    enable = lib.mkEnableOption "Enable ${name} dotfiles" // { default = true; };
    dir = lib.mkOption {
      type = lib.types.str;
      default = defaultDir;
      description = "Directory to place ${name} configuration files";
    };
  };

in {
  options.my.dotfiles = {
    enable = lib.mkEnableOption "Enable dotfiles management" // { default = true; };
    
    aichat = mkDotfileOption "aichat" ".config/aichat";
    ghostty = mkDotfileOption "ghostty" ".config/ghostty";
    git = mkDotfileOption "git" ".config/git";
    karabiner = mkDotfileOption "karabiner-elements" ".config/karabiner";
    kitty = mkDotfileOption "kitty" ".config/kitty";
    lazygit = mkDotfileOption "lazygit" ".config/lazygit";
    nvim = mkDotfileOption "neovim" ".config/nvim-lua";
    sops = mkDotfileOption "sops" ".config/sops";
  };

  config = lib.mkIf cfg.enable {
    
    # aichat
    home.file."${cfg.aichat.dir}" = lib.mkIf cfg.aichat.enable {
      source = ./aichat;
      recursive = true;
    };

    # ghostty
    home.file."${cfg.ghostty.dir}" = lib.mkIf cfg.ghostty.enable {
      source = ./ghostty;
    };

    # git
    home.file."${cfg.git.dir}" = lib.mkIf cfg.git.enable {
      source = ./git;
    };

    # karabiner (Darwin only)
    home.file."${cfg.karabiner.dir}" = lib.mkIf (cfg.karabiner.enable && pkgs.stdenv.isDarwin) {
      source = ./karabiner;
    };

    # kitty
    home.file."${cfg.kitty.dir}" = lib.mkIf cfg.kitty.enable {
      source = ./kitty;
    };

    # lazygit
    home.file."${cfg.lazygit.dir}" = lib.mkIf cfg.lazygit.enable {
      source = ./lazygit;
    };

    # neovim
    home.file."${cfg.nvim.dir}" = lib.mkIf cfg.nvim.enable {
      source = ./nvim;
      recursive = true;
    };

    # sops
    home.file."${cfg.sops.dir}" = lib.mkIf cfg.sops.enable {
      source = ./sops;
    };
  };
} 