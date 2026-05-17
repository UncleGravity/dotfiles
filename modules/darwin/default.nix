{
  imports = [
    ../common

    # ── Baseline (always applied) ─────────────────────────────
    ./networking.nix
    ./nh.nix
    ./nix.nix
    ./pkgs.nix
    ./security.nix
    ./shells.nix
    ./system.nix
    ./users.nix

    # ── Features (opt in: my.<feature>.enable) ────────────────
    ./features/apfs-snapshots.nix
    ./features/homebrew.nix

    # ── Vendored upstream modules ─────────────────────────────
    ./vendor/nh.nix # TODO: REMOVE when nix-darwin/nix-darwin/pull/942 is merged
  ];

  # Karabiner-Elements
  # TODO: Broken for now, install with homebrew instead.
  # https://github.com/nix-darwin/nix-darwin/issues/1041
  # services.karabiner-elements.enable = lib.mkDefault true;

  #############################################################
  #  Tailscale
  #############################################################
  # services.tailscale.enable = true;
}
