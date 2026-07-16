{
  imports = [
    # ── Baseline (always applied) ─────────────────────────────
    ./caches.nix
    ./sops.nix
    ./ssh-keys.nix

    # ── Features (opt in: my.<feature>.enable) ────────────────
    ./features/env.nix
    ./features/ntfy.nix
  ];
}
