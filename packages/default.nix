{
  pkgs,
  system,
  wrapper-manager,
  ...
}: {
  scripts = (pkgs.callPackage ./scripts {inherit system;}).toplevel; # collection
  wrappers = (pkgs.callPackage ./wrappers {inherit wrapper-manager;}).toplevel; # collection
  greet = pkgs.callPackage ./greet.nix {inherit pkgs;};
  # my_package = pkgs.callPackage ./my_package { inherit inputs system; }; # single package
}
