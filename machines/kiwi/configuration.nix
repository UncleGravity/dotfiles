{ self, config, pkgs, inputs, options, username, hostname, systemStateVersion, ... }:
let
  enableXServer = true;
  MODULES_DIR = "${self}/modules";
in
{
  imports =
    [
      ./hardware.nix
      ../_default/nixos/configuration.nix
      ./zfs.nix
      "${MODULES_DIR}/nixos/docker.nix"
      "${MODULES_DIR}/sops.nix"
      "${MODULES_DIR}/samba.nix"

      # Auto-generates fileSystems entries originally found in hardware.nix
      inputs.disko.nixosModules.disko 
      ./disko.nix
    ];

  # ---------------------------------------------------------------------------
  # X11
  services.xserver.enable = enableXServer;
  services.xserver.autorun = enableXServer;
   
  # Enable the GNOME Desktop Environment.
  services.xserver.displayManager.gdm.enable = enableXServer;
  services.xserver.desktopManager.gnome.enable = true;

  # ---------------------------------------------------------------------------
  system.stateVersion = systemStateVersion; # no touch
}

