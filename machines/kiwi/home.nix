{ config, pkgs, inputs, homeStateVersion, self, ... }:

let
  HOME_DIR = "${self}/home";
in
{

  imports = [
    "${HOME_DIR}/_core.nix"
  ];

  programs.home-manager.enable = true; # Let Home Manager install and manage itself.
  home.stateVersion = homeStateVersion; # don't touch this or everybody dies
}
