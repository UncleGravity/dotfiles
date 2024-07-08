{ config, lib, pkgs, ... }:

{
  users.users.angel.extraGroups = [ "plugdev" ];
  
  users.groups.plugdev = {};
  
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTR{idVendor}=="1d50", ATTR{idProduct}=="6089", GROUP="plugdev", MODE="0666"
  '';

  environment.systemPackages = [ pkgs.hackrf ];
}