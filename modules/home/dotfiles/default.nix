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

    ghostty = {enable = mkEnable "ghostty";};
    karabiner = {enable = mkEnable "karabiner";}; # Darwin-only below
    kitty = {enable = mkEnable "kitty";};
    sops = {enable = mkEnable "sops";}; # single file
  };

  ##### 2.  Configuration #####################################################

  config = lib.mkIf cfg.enable {
    # --- directory-style dotfiles (link to $XDG_CONFIG_HOME/<name>) ----------
    xdg.configFile = {
      "ghostty" = lib.mkIf cfg.ghostty.enable {
        source = ./ghostty;
      };

      "karabiner" = lib.mkIf (cfg.karabiner.enable && pkgs.stdenv.isDarwin) {
        source = ./karabiner;
      };

      "kitty" = lib.mkIf cfg.kitty.enable {
        source = ./kitty;
      };
    };

    # --- single file (lives directly in $HOME) -------------------------------
    home.file = {
      ".sops.yaml" = lib.mkIf cfg.sops.enable { source = ./sops/.sops.yaml; };
    };
  };
}
