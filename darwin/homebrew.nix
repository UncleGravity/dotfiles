{ config, lib, pkgs, ... }:

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
      # "aria2"  # download tool
      "cyme"
      "lsusb"
      "hackrf"
    ];

    # `brew install --cask`
    casks = [
      # "google-chrome"
      "alacritty"
      "cursor"
      "ghostty"
      "kitty"
      "wezterm"
      "hammerspoon"
      "macfuse"

      # TODO: Move to nix-darwin: services.karabiner-elements.enable. 
      # https://github.com/LnL7/nix-darwin/blob/master/modules/services/karabiner-elements/default.nix
      "karabiner-elements" 
    ];
  };
}
