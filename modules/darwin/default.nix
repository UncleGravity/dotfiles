{ config }:
{
  imports = [
    ../common
    ./networking.nix
    ./nh.nix
    ./nix.nix
    ./security.nix
    ./shells.nix
    ./system.nix
    ./users.nix
    # Feature modules
    ./apfs-snapshots.nix
    ./homebrew.nix
    ./_nh.nix # TODO: REPLACE when nix-darwin/nix-darwin/pull/942 is merged
  ];

  # --------------------------------------------------------------------------
  # Default Darwin Modules
  my = {
    homebrew.enable = true;
    apfs-snapshots.enable = true;
  };

  #############################################################
  #  Packages
  #############################################################
  environment.systemPackages = config.my.common.systemPackages;

  # Karabiner-Elements
  # TODO: Broken for now, install with homebrew instead.
  # https://github.com/nix-darwin/nix-darwin/issues/1041
  # services.karabiner-elements.enable = lib.mkDefault true;

  #############################################################
  #  Tailscale
  #############################################################
  # services.tailscale.enable = true;
}
