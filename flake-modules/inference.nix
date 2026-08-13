{inputs, ...}: let
  inherit (inputs.nixpkgs) lib;
in {
  flake = {
    lib.inference = import ../packages/inference/nix/lib {inherit lib;};
    nixosModules.inference = import ../packages/inference/nix/modules;
  };
}
