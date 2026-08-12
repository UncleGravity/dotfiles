{inputs, ...}: {
  perSystem = {
    pkgs,
    system,
    ...
  }: {
    packages = import ../packages {
      inherit inputs pkgs system;
      inherit (pkgs) lib;
    };
  };
}
