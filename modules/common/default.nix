{
  imports = [
    # ── Baseline (always applied) ─────────────────────────────
    ./caches.nix
    ./utility-vars.nix
    ./sops.nix
    ./ssh-keys.nix

    # ── Features (opt in: my.<feature>.enable) ────────────────
    ./features/env.nix
    ./features/ntfy.nix
  ];
}
