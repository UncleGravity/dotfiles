{ config, lib, pkgs, ... }:

{
  # hardware.hackrf.enable = true; # doesn't work for some reason, maybe send pull request
  # https://github.com/NixOS/nixpkgs/blob/d1b9c95fdfe16e551737edc6e0b9646cfb9a6850/nixos/modules/hardware/hackrf.nix
  
  users.users.angel.extraGroups = [ "plugdev" ];
  
  users.groups.plugdev = {};
  
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTR{idVendor}=="1d50", ATTR{idProduct}=="6089", GROUP="plugdev", MODE="0666"
  '';

  environment.systemPackages = [ pkgs.hackrf ];
}