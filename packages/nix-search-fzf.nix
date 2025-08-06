{
  pkgs,
  lib,
  ...
}: let
  configFile = pkgs.writeText "nix-search-tv-config.json" /* json */ ''
    {
      "indexes": ["darwin", "nixpkgs", "home-manager", "nur", "nixos"]
    }
  '';
in
pkgs.writeShellApplication {
  name = "nix-search-fzf";
  runtimeInputs = [
      pkgs.nix-search-tv
      pkgs.fzf
  ];
  text = ''
    ${lib.getExe pkgs.nix-search-tv} print --config ${configFile} | fzf --preview 'nix-search-tv preview {}' --scheme history
  '';
}
