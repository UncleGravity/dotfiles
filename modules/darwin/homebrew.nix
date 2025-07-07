{
  config,
  lib,
  pkgs,
  inputs,
  username,
  ...
}: let
  cfg = config.my.homebrew;
in {
  options.my.homebrew = {
    enable = lib.mkEnableOption "Homebrew with curated casks and apps";

    cleanup = lib.mkOption {
      type = lib.types.enum ["none" "uninstall" "zap"];
      default = "none";
      description = "How to cleanup unmanaged formulae on activation";
    };

    extraCasks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional casks to install beyond the default set";
    };

    extraMasApps = lib.mkOption {
      type = lib.types.attrsOf lib.types.int;
      default = {};
      description = "Additional Mac App Store apps to install";
    };
  };

  config = lib.mkIf cfg.enable {
    homebrew = {
      enable = true;

      onActivation = {
        autoUpdate = false;
        cleanup = cfg.cleanup;
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
      masApps =
        {
          "Paste – Limitless Clipboard" = 967805235;
        }
        // cfg.extraMasApps;

      # `brew install --cask`
      casks =
        [
          "anki"
          "google-chrome"
          "digikam"

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
          "raspberry-pi-imager"

          # Keyboard
          "karabiner-elements" # TODO: Move to nix-darwin: services.karabiner-elements.enable
          "raycast"
        ]
        ++ cfg.extraCasks;
    };
  };
}
