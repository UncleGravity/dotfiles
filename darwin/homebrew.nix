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
    # TODO Feel free to add your favorite apps here.
    brews = [
      # "aria2"  # download tool
      "cyme"
      "lsusb"
      "hackrf"
    ];

    # `brew install --cask`
    # TODO Feel free to add your favorite apps here.
    casks = [
      # "google-chrome"
      "cursor"
      "kitty"
      "wezterm"

      # TODO: Move to nix-darwin: services.karabiner-elements.enable. 
      # https://github.com/LnL7/nix-darwin/blob/master/modules/services/karabiner-elements/default.nix
      "karabiner-elements" 
    ];
  };
}
