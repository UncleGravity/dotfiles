{
  lib,
  username,
  ...
}: {
  # --------------------------------------------------------------------------
  # Nix (flakes, caches, GC)
  nix = {
    channel.enable = false; # flake gang

    settings = {
      experimental-features = ["nix-command" "flakes"]; # Enable Flakes
      sandbox = "relaxed"; # Allow packages with __noChroot = false; to use external dependencies
      auto-optimise-store = lib.mkDefault false; # Avoiding some heavy IO

      # -------------------------------
      trusted-users = ["root" username]; # Allow root and ${username} to use nix-command (required by devenv for cachix to work)
    };
  };
}
