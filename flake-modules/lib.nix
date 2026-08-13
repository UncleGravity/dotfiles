{inputs, ...}: let
  inherit (inputs.nixpkgs) lib;
in {
  flake.lib = {
    inference = import ../packages/inference/nix/lib {inherit lib;};
    sparkCluster.nodes = import ../modules/clan/spark-cluster/inventory.nix;
  };
}
