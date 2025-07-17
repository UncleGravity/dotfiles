{
  pkgs,
  lib,
  ...
}:
###############################################################################
#  System-level packages shared by all machines.
#
#  Intended for `environment.systemPackages` in NixOS / nix-darwin configs.
###############################################################################
let
  # Core CLI tools that make sense on *both* Linux and Darwin.
  systemPackages = with pkgs; [
    curl
    wget
    vim
    git
  ];
in {
  options.my.common.systemPackages = lib.mkOption {
    type = with lib.types; listOf package;
    default = systemPackages;
    description = ''
      System-wide utilities that are installed via
      `environment.systemPackages` for every host.
    '';
  };
}
