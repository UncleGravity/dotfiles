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

  # Only keep brews and casks managed by nix
  my.homebrew.cleanup = "zap";

  # Example: Override system packages for this specific machine
  # environment.systemPackages = with pkgs; [ git vim neovim ]; # This replaces the list from base

  # Example: Override a specific system default for this machine
  # system.defaults.dock.autohide = false; # Keep the dock visible on this machine

  # system.stateVersion is now set at the flake level in mkDarwin
}
