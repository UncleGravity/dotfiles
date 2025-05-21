{ config, lib, pkgs, inputs, username, ... }:

{
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = false;
      # 'zap': uninstalls all formulae(and related files) not listed here.
      # cleanup = "zap";
    };

    taps = [
    ];

    # `brew install`
    brews = [
      # "hackrf"
      # fuse-t
    ];

    # `brew install --cask`
    casks = [
      "anki"
      "google-chrome"
      "cursor"
      "ghostty"
      "kitty"
      "kicad"
      "raycast"
      "obsidian"
      "private-internet-access"
      "freedom"
      "discord"
      "microsoft-teams"
      "nrfutil"

      # TODO: Move to nix-darwin: services.karabiner-elements.enable 
      "karabiner-elements" 
    ];
  };
}
