{ pkgs, inputs, system, ... }:

{
  scripts = pkgs.callPackage ./scripts { inherit system; };
  # my_package = pkgs.callPackage ./my_package { inherit inputs system; };
}
