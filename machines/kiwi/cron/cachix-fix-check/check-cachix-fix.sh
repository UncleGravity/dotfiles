#!/usr/bin/env bash
set -euo pipefail

source_root="$(
  nix build --impure --refresh --no-link --print-out-paths --expr '
    let
      nixpkgs = builtins.getFlake "github:NixOS/nixpkgs/nixos-unstable";
      cachix = nixpkgs.legacyPackages.x86_64-linux.cachix;
    in
      builtins.dirOf cachix.src
  '
)"
activate="$source_root/cachix/src/Cachix/Deploy/Activate.hs"

test -r "$activate"

if rg --fixed-strings --quiet '"extra-trusted-public-keys"' "$activate"; then
  ntfy pub \
    --title "Cachix fix available" \
    --message "Cachix's trusted-key fix is available in nixos-unstable. Remove the local patch and package override."
fi
