{
  lib,
  username,
  ...
}: {
  #############################################################
  #  Nix
  #############################################################

  nix = {
    channel.enable = false; # Flake gang

    settings = {
      experimental-features = "nix-command flakes";

      # -------------------------------
      trusted-users = [username];

      # -------------------------------
      # Bug
      # Disable auto-optimise-store because of this issue:
      #   https://github.com/NixOS/nix/issues/7273
      # "error: cannot link '/nix/store/.tmp-link-xxxxx-xxxxx' to '/nix/store/.links/xxxx': File exists"
      auto-optimise-store = lib.mkDefault false;
    };

    # https://github.com/NixOS/nix/issues/7273#issuecomment-2295429401
    optimise.automatic = lib.mkDefault true;
  };
}
