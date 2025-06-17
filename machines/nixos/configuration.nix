{ config, pkgs, inputs, options, username, hostname, systemStateVersion, self, ... }:
let
  enableXServer = true;
  MODULES_DIR = "${self}/modules";
in
{
  imports =
    [
      ./hardware.nix
      ../_default/nixos/configuration.nix
      "${MODULES_DIR}/sops.nix"
      "${MODULES_DIR}/nixos/docker.nix"
      "${MODULES_DIR}/nixos/hackrf.nix"
      "${MODULES_DIR}/nixos/display-manager.nix"
      # "${MODULES_DIR}/nixos/escape-hatch.nix"
    ];

  # ---------------------------------------------------------------------------
  # X11
  my.displayManager = {
    enable = true;
    desktop = "gnome";
  };

  # ---------------------------------------------------------------------------
  # Enable CUPS to print documents.
  services.printing.enable = true;

  # ---------------------------------------------------------------------------
  system.stateVersion = systemStateVersion; # no touch
}