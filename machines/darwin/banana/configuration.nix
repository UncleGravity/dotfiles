# Configuration for the 'my-macbook' machine
{ inputs, ... }:
{
  imports = [
    ./linux-builder.nix
  ];

  # --- Role profiles ---
  # Profiles are NixOS-only for now — every darwin host is a workstation+graphical
  # laptop. Re-enable here if a darwin module ever gates on these flags.
  # my.profiles = {
  #   workstation.enable = true;
  #   graphical.enable = true;
  # };

  # SECRETS
  my.env.work.enable = true;

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

  # Homebrew
  my.homebrew.enable = true;
  my.homebrew.cleanup = "zap"; # Only keep brews and casks managed by nix

  # Enable nix-linux-builder for building Linux packages on Darwin
  # nix.linux-builder.enable = true;

  # Example: Override system packages for this specific machine
  # environment.systemPackages = with pkgs; [ git vim neovim ]; # This replaces the list from base

  # Example: Override a specific system default for this machine
  # system.defaults.dock.autohide = false; # Keep the dock visible on this machine
}
