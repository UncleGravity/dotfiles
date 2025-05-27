{ self, config, pkgs, inputs, options, username, hostname, systemStateVersion, ... }:
let
  MODULES_DIR = "${self}/modules";
in
{
  imports =
    [
      # Disko auto-generates fileSystems entries (originally managed in hardware.nix)
      inputs.disko.nixosModules.disko 
      ./disko.nix
      ./hardware.nix
      ../_default/nixos/configuration.nix
      ./zfs.nix
      "${MODULES_DIR}/sops.nix"
      "${MODULES_DIR}/nixos/tailscale.nix"
      "${MODULES_DIR}/nixos/docker.nix"
      "${MODULES_DIR}/nixos/samba.nix"
      "${MODULES_DIR}/nixos/guacamole/"
      "${MODULES_DIR}/nixos/display-manager.nix"

    ];

  # ---------------------------------------------------------------------------
  # X11 / GNOME
  displayManager = {
    enable = true;
    desktop = "gnome";
    rdp.enable = true; # For Guacamole
  };

  # ---------------------------------------------------------------------------
  # Escape Hatch
  programs.nix-ld.enable = true;

  # ---------------------------------------------------------------------------
  system.stateVersion = systemStateVersion; # no touch
}

