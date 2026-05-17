{
  imports = [
    # ── Baseline (always applied) ─────────────────────────────
    ./caches.nix
    ./sops.nix
    ./ssh-keys.nix

    # ── Schemas (options-only, consumed elsewhere) ────────────
    ./profiles.nix

    # ── Features (opt in: my.<feature>.enable) ────────────────
    ./features/env.nix
    ./features/ntfy.nix
  ];
}
