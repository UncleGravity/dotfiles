{
  config,
  pkgs,
  inputs,
  options,
  username,
  hostname,
  systemStateVersion,
  self,
  ...
}: {
  imports = [
    ./hardware.nix
    "${self}/modules/nixos/_core.nix"
  ];

  # ---------------------------------------------------------------------------
  # Enable additional modules for this VM
  my.hackrf.enable = true;

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
