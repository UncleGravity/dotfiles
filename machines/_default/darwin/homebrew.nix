{ config, lib, pkgs, inputs, username, ... }:

{
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = false;
      # cleanup = "zap"; # uninstalls all formulae(and related files) not managed by nix.
    };

    taps = [
    ];

    # `brew install`
    brews = [
      # "hackrf"
      # fuse-t
    ];

    # masApps
    # find the app id with `mas search <app name>`
    masApps = {
      "Paste – Limitless Clipboard" = 967805235;
    };

    # `brew install --cask`
    casks = [
      "anki"
      "google-chrome"

      # Protect  battery
      "aldente"

      # Code
      "cursor"
      "zed"

      # Terminal
      "ghostty"
      "kitty"

      # VM
      "utm"

      # Note
      "obsidian"

      # VPN
      "tailscale"
      "private-internet-access"
      "freedom"

      # Chat
      "discord"
      "microsoft-teams"
      # "slack"

      # EE
      "kicad"
      "nrfutil"

      # Keyboard
      "karabiner-elements" # TODO: Move to nix-darwin: services.karabiner-elements.enable
      "raycast"
    ];
  };
}
