# Configuration for the 'my-macbook' machine
{ pkgs, lib, inputs, username, hostname, self, systemStateVersion, ... }:

{
  imports = [
    "${self}/modules/darwin/_core.nix"
    "${self}/modules/darwin/homebrew.nix"
  ];

  # --- Overrides or Machine-Specific Settings ---
  # Any setting here will override the corresponding 'mkDefault' setting in base-configuration.nix

  # Only keep brews and casks managed by nix
  homebrew.onActivation.cleanup = "zap";

  # Example: Override system packages for this specific machine
  # environment.systemPackages = with pkgs; [ git vim neovim ]; # This replaces the list from base

  # Example: Override a specific system default for this machine
  # system.defaults.dock.autohide = false; # Keep the dock visible on this machine

  system.stateVersion = systemStateVersion; # Don't change this
}
