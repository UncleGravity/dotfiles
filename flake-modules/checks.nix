{
  inputs,
  lib,
  ...
}: {
  perSystem = {
    pkgs,
    system,
    ...
  }: {
    checks = import ../packages/inference/tests/nix {
      inherit pkgs;
      inferenceLib = inputs.self.lib.inference;
      inferencePackage = inputs.self.packages.${system}.inference;
      kiwiConfiguration = inputs.self.nixosConfigurations.kiwi;
      sparkConfiguration = inputs.self.nixosConfigurations.spark-01;
      sparkConfigurations = lib.genAttrs [
        "spark-01"
        "spark-02"
        "spark-03"
        "spark-04"
      ] (name: inputs.self.nixosConfigurations.${name});
    };
  };
}
