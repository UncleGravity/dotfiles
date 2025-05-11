{ config, pkgs, inputs, ... }:

let
  ROOT_DIR = ../../.;
  HOME_MODULES_DIR = "${ROOT_DIR}/home";
in
{

  imports = [
    "${HOME_MODULES_DIR}/_core.nix"
  ];

  programs.home-manager.enable = true; # Let Home Manager install and manage itself.
  home.stateVersion = "24.05"; # don't touch this or everybody dies
}
