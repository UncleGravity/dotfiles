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
      "homebrew/services"
    ];

    # `brew install`
    brews = [
      "hackrf"
    ];

    # `brew install --cask`
    casks = [
      "anki"
      "google-chrome"
      "cursor"
      "ghostty"
      "kitty"
      "kicad"
      "hammerspoon"
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
