{
  config,
  lib,
  pkgs,
  ...
}: {
  #############################################################
  #  System packages
  #############################################################
  environment.systemPackages = config.my.common.systemPackages;

  #############################################################
  #  Zsh
  #############################################################
  programs.zsh = {
    # Create /etc/zshrc that loads the nix-darwin environment.
    # this is required if you want to use darwin's default shell - zsh (instead of bash)
    enable = lib.mkDefault true;

    # IMPORTANT - This prevents compinit from running on /etc/zshrc,
    # which noticeably slows down shell startup. Run compinit from user zshrc instead.
    # This is (I think) mostly necessary because I am using a custom zshrc file instead of letting nix manage it.
    enableGlobalCompInit = lib.mkDefault false;
    # environment.pathsToLink = [ "/share/zsh" ];
  };

  environment.shells = lib.mkDefault [pkgs.zsh]; # Use nix managed zsh (probably more frequently updated
}
