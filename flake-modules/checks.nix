{inputs, ...}: {
  perSystem = {
    pkgs,
    system,
    ...
  }: {
    checks = import ../packages/inference/tests/nix {
      inherit pkgs;
      inferenceLib = inputs.self.lib.inference;
      inferencePackage = inputs.self.packages.${system}.inference;
      sparkConfiguration = inputs.self.nixosConfigurations.spark-01;
    };
  };
}
