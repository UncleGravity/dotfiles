# Configuration for the 'my-macbook' machine
{
  inputs,
  username,
  ...
}: {
  imports = [
    ../../modules/darwin
    inputs.nix-homebrew.darwinModules.nix-homebrew
    ./builders
  ];

  clan.core.deployment.requireExplicitUpdate = true;

  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 6;

  # Home
  home-manager.users.${username}.imports = [./home.nix];

  nix-homebrew = {
    enable = true;
    user = "angel";
    autoMigrate = true;
    mutableTaps = false;
    taps = {
      "homebrew/homebrew-core" = inputs.homebrew-core;
      "homebrew/homebrew-cask" = inputs.homebrew-cask;
    };
  };

  my = {
    # SECRETS
    env.work.enable = true;

    # --- Overrides or Machine-Specific Settings ---
    # Any setting here will override the corresponding 'mkDefault' setting in base-configuration.nix

    # Enable APFS snapshots service
    apfs-snapshots = {
      enable = false;
      interval = 3600; # Take snapshots every hour (3600 seconds)
      keepCount = 24; # Keep 24 snapshots
      # Log to a custom location if desired
      # logPath = "/var/log/apfs-snapshots.log"; # This is the default
    };

    # Homebrew
    homebrew = {
      enable = true;
      cleanup = "zap"; # Only keep brews and casks managed by nix
    };
  };

  # Example: Override system packages for this specific machine
  # environment.systemPackages = with pkgs; [ git vim neovim ]; # This replaces the list from base

  # Example: Override a specific system default for this machine
  # system.defaults.dock.autohide = false; # Keep the dock visible on this machine
}
