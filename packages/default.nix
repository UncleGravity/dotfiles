{
  pkgs,
  system,
  wrapper-manager,
  ...
}: {
  scripts = pkgs.callPackage ./scripts { inherit system; };
  # my_package = pkgs.callPackage ./my_package { inherit inputs system; };

  # Wrapped packages built with wrapper-manager
  wrapped = pkgs.callPackage ./wrappers { inherit wrapper-manager; };
}
