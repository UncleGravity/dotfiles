{ config, pkgs, inputs, ... }:

let
  ROOT_DIR = ../../.;
  HOME_MODULES_DIR = "${ROOT_DIR}/home";
  DOTFILES_DIR = "${HOME_MODULES_DIR}/dotfiles";
in
{

  imports = [
    "${HOME_MODULES_DIR}/_core.nix"
  ];

  home.file = {
    ".config/karabiner" = {
      source = "${DOTFILES_DIR}/karabiner";
    };
  };

  programs.home-manager.enable = true; # Let Home Manager install and manage itself.
  home.stateVersion = "24.05"; # don't touch this or everybody dies
}
