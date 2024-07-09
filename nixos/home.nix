{ config, pkgs, inputs, ... }:

let
  ROOT_DIR = ../.;
  HOME_MODULES_DIR = "${ROOT_DIR}/home";
in
{

  imports = [
    # ./vscode-server.nix # NIXOS ONLY: I would normally install this as a system package, but it's easier with home-manager https://github.com/nix-community/nixos-vscode-server?tab=readme-ov-file#home-manager
    "${HOME_MODULES_DIR}/_core.nix"
  ];

  programs.home-manager.enable = true; # Let Home Manager install and manage itself.
  home.stateVersion = "24.05"; # don't touch this or everybody dies
}
