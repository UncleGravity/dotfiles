{
  config,
  pkgs,
  inputs,
  options,
  username,
  hostname,
  ...
}: {
  imports = [
    # ./hardware.nix
    "${inputs.self}/modules/nixos/_core.nix"
    ./qemu.nix
    # ./vfkit.nix
  ];

  # ---------------------------------------------------------------------------
  # Enable additional modules for this VM
  my.hackrf.enable = true;

  # ---------------------------------------------------------------------------
  # X11
  my.displayManager = {
    enable = false;
    desktop = "gnome";
  };

  users.users.${username}.password = "angel"; # Set a simple password for SSH access

  # ---------------------------------------------------------------------------
  # Enable CUPS to print documents.
  services.printing.enable = true;
}
