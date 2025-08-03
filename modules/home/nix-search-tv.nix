{
  pkgs,
  lib,
  inputs,
  ...
}: let
  configFile = pkgs.writeText "nix-search-tv-config.json" /* json */ ''
    {
      "indexes": ["nixpkgs", "home-manager", "nur", "nixos"]
    }
  '';

  # Wrap a nstv with config file
  nix-search-tv = inputs.wrapper-manager.lib.wrapWith pkgs {
    basePackage = pkgs.nix-search-tv;
    appendFlags = ["--config" "${configFile}"];
  };

  # Alias for quick search
  ns = pkgs.writeShellApplication {
    name = "ns";
    runtimeInputs = [
        pkgs.nix-search-tv
        pkgs.fzf
        nix-search-tv
    ];
    text = ''
      ${lib.getExe nix-search-tv} print | fzf --preview 'nix-search-tv preview {}' --scheme history
    '';
  };
in {
  home.packages = [
    nix-search-tv
    ns
  ];
}
