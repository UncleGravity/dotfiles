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
      # "${MODULES_DIR}/nixos/escape-hatch.nix"
    ];

  # default username: admin@kasm.local
  # default password: kasmweb
  services.kasmweb.enable = true;

  # ---------------------------------------------------------------------------
  # X11
  services.xserver.enable = enableXServer;
  services.xserver.autorun = enableXServer;
   
  # Enable the GNOME Desktop Environment.
  services.xserver.displayManager.gdm.enable = enableXServer;
  services.xserver.desktopManager.gnome.enable = true;

  # ---------------------------------------------------------------------------
  # Enable CUPS to print documents.
  services.printing.enable = true;

  # ---------------------------------------------------------------------------
  system.stateVersion = systemStateVersion; # no touch
}