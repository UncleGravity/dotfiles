# Configuration for the 'my-macbook' machine
{ pkgs, lib, inputs, username, hostname, ... }:

{
  imports = [
    ./config-default.nix # Import common settings
    ./homebrew.nix
  ];

  # --- Overrides or Machine-Specific Settings ---
  # Any setting here will override the corresponding 'mkDefault' setting in base-configuration.nix

  # Example: Override system packages for this specific machine
  # environment.systemPackages = with pkgs; [ git vim neovim ]; # This replaces the list from base

  # Example: Override a specific system default for this machine
  # system.defaults.dock.autohide = false; # Keep the dock visible on this machine

  system.stateVersion = 6; # Don't change this
}
