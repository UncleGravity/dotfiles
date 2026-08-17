{
  imports = [
    # ── Baseline (always applied) ─────────────────────────────
    ./caches.nix
    ./cachix.nix
    ./clan-machine.nix
    ./home-manager.nix
    ./nixpkgs.nix
    ./sops.nix
    ./ssh-keys.nix

    # ── Features (opt in: my.<feature>.enable) ────────────────
    ./features/env.nix
    ./features/ntfy.nix
  ];
}
