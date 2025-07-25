{
  config,
  lib,
  pkgs,
  username,
  ...
}: let
  cfg = config.my.hackrf;
in {
  options.my.hackrf = {
    enable = lib.mkEnableOption "HackRF USB device support";
  };

  config = lib.mkIf cfg.enable {
    # hardware.hackrf.enable = true; # doesn't work for some reason, maybe send pull request
    # https://github.com/NixOS/nixpkgs/blob/d1b9c95fdfe16e551737edc6e0b9646cfb9a6850/nixos/modules/hardware/hackrf.nix

    users.users.${username}.extraGroups = ["plugdev"];
    users.groups.plugdev = {}; # Create the plugdev group if it doesn't exist

    # Add udev rule to allow access to the hackrf device
    services.udev.extraRules = ''
      SUBSYSTEM=="usb", ATTR{idVendor}=="1d50", ATTR{idProduct}=="6089", GROUP="plugdev", MODE="0666"
    '';

    # Install the hackrf package
    environment.systemPackages = [pkgs.hackrf];
  };
}
