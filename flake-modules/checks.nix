{inputs, ...}: {
  perSystem = {
    pkgs,
    system,
    ...
  }: let
    nixosSystem =
      if pkgs.stdenv.hostPlatform.isx86_64
      then "x86_64-linux"
      else "aarch64-linux";
  in {
    checks = import ../packages/inference/tests/nix {
      inherit pkgs;
      inferenceLib = inputs.self.lib.inference;
      inferencePackage = inputs.self.packages.${system}.inference;
      nixosLib = inputs.nixpkgs.lib;
      nixosPkgs = inputs.nixpkgs.legacyPackages.${nixosSystem};
    };
  };
}
