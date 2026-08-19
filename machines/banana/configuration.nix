# Configuration for the 'my-macbook' machine
{username, ...}: {
  imports = [
    ../../modules/darwin
    ./builders
  ];

  # Home
  home-manager.users.${username}.imports = [./home.nix];

  # Only update when explicitly targetted with `clan machines update banana`
  clan.core.deployment.requireExplicitUpdate = true;

  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 6;

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
}
