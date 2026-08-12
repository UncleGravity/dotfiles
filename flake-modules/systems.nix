{inputs, ...}: let
  overlays = import ../overlays {inherit inputs;};
in {
  systems = [
    "aarch64-linux"
    "x86_64-linux"
    "aarch64-darwin"
  ];

  perSystem = {system, ...}: {
    _module.args.pkgs = import inputs.nixpkgs {
      inherit system overlays;
      config.allowUnfree = true;
    };
  };
}
