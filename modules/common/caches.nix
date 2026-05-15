{...}: {
  # Binary caches shared by every host (NixOS + Darwin).
  # If a host needs to deviate, override with `lib.mkForce`.
  nix.settings = {
    substituters = [
      "https://nix-community.cachix.org?priority=41"
      "https://numtide.cachix.org?priority=42"
      "https://unclegravity-nix.cachix.org?priority=43" # Personal
      "https://nix-cache.fossi-foundation.org" # LibreLane
    ];

    trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
      "unclegravity-nix.cachix.org-1:fnXTPHMhvKwMrqyU/z00iyf8SkUuK0YP2PpCYb1t3nI=" # Personal
      "nix-cache.fossi-foundation.org:3+K59iFwXqKsL7BNu6Guy0v+uTlwsxYQxjspXzqLYQs=" # LibreLane
    ];

    always-allow-substitutes = true;
  };
}
