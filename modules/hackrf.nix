{ config, lib, pkgs, ... }:

{
  options.hackrf = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to enable the HackRF custom configuration.";
    };
    username = lib.mkOption {
      type = lib.types.str;
      # You might want to make this mandatory by removing the default,
      # or keep "angel" as a default if it makes sense.
      # default = "angel"; 
      description = "Username for HackRF device permissions. This user will be added to the plugdev group.";
    };
  };

  config = lib.mkIf config.hackrf.enable {
    # hardware.hackrf.enable = true; # doesn't work for some reason, maybe send pull request
    # https://github.com/NixOS/nixpkgs/blob/d1b9c95fdfe16e551737edc6e0b9646cfb9a6850/nixos/modules/hardware/hackrf.nix
    
    users.users."${config.hackrf.username}".extraGroups = [ "plugdev" ];
    
    users.groups.plugdev = {}; # Ensures plugdev group exists
    
    services.udev.extraRules = ''
      SUBSYSTEM=="usb", ATTR{idVendor}=="1d50", ATTR{idProduct}=="6089", GROUP="plugdev", MODE="0666"
    '';

    environment.systemPackages = [ pkgs.hackrf ];
  };
}