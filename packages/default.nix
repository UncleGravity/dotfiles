{ pkgs, inputs, system, ... }:

{
  scripts = pkgs.callPackage ./scripts { inherit system; };
  opencode = pkgs.callPackage ./opencode { inherit inputs system; };
} 