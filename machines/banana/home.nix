{ config, pkgs, inputs, self, ... }:

let
  HOME_DIR = "${self}/home";
  DOTFILES_DIR = "${HOME_DIR}/dotfiles";
in
{

  imports = [
    "${HOME_DIR}/_core.nix"
  ];

  home.file = {
    ".config/karabiner" = {
      source = "${DOTFILES_DIR}/karabiner";
    };
  };

  programs.home-manager.enable = true; # Let Home Manager install and manage itself.
  home.stateVersion = "24.05"; # don't touch this or everybody dies
}
