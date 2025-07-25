# Configuration for the 'my-macbook' machine
{
  pkgs,
  lib,
  inputs,
  username,
  hostname,
  ...
}: {
  imports = [
    "${inputs.self}/modules/darwin/_core.nix"
  ];

  # --- Overrides or Machine-Specific Settings ---
  # Any setting here will override the corresponding 'mkDefault' setting in base-configuration.nix

  # Enable APFS snapshots service
  my.apfs-snapshots = {
    enable = true;
    interval = 3600; # Take snapshots every hour (3600 seconds)
    keepCount = 24; # Keep 24 snapshots
    # Log to a custom location if desired
    # logPath = "/var/log/apfs-snapshots.log"; # This is the default
  };

  # Lots of legacy homebrew stuff, keep it for now
  my.homebrew.cleanup = "none";

  # Example: Override system packages for this specific machine
  # environment.systemPackages = with pkgs; [ git vim neovim ]; # This replaces the list from base

  # Example: Override a specific system default for this machine
  # system.defaults.dock.autohide = false; # Keep the dock visible on this machine

  # system.stateVersion is now set at the flake level in mkDarwin
}
