{
  inputs,
  pkgs,
  system,
  wrapper-manager,
  lib,
  ...
}: let
  # Packages go here
  individualPackages = {
    greet = pkgs.callPackage ./greet.nix {inherit pkgs;};
    bootstrap = pkgs.callPackage ./bootstrap.nix {inherit pkgs;};
    optnix = pkgs.callPackage ./optnix.nix {inherit inputs pkgs lib;};
    optnix-fzf = pkgs.callPackage ./optnix-fzf.nix {inherit inputs pkgs lib;};
    nix-search-fzf = pkgs.callPackage ./nix-search-fzf.nix {inherit inputs pkgs lib;};
  };

  # Halt. Everything below this line is boilerplate.
  # -------------------------------------------------------------------------------------

  # Bundle individual packages together
  packagesBundle = pkgs.symlinkJoin {
    name = "my packages bundle";
    paths = builtins.attrValues individualPackages;
    meta = {
      description = "Bundle of all my packages";
      platforms = lib.platforms.all;
    };
  };
  scriptsModule = pkgs.callPackage ./scripts {inherit system;};
  wrappersModule = pkgs.callPackage ./wrappers {inherit wrapper-manager inputs;};
in {
  # Return collections
  # use directly:     inputs.packages.<system>.scripts|wrappers|packages
  # use with overlay: pkgs.my.scripts|wrappers|packages
  scripts = scriptsModule.toplevel; # collection
  wrappers = wrappersModule.toplevel; # collection
  packages = packagesBundle; # collection
  # my_package = pkgs.callPackage ./my_package { inherit inputs system; }; # single package

} # Return individual packages
  # use in flake: inputs.packages.<system>.<package_name>
  # use in terminal: nix run .#<package_name>
  // individualPackages # all packages
  // scriptsModule.packages # all scripts
  // wrappersModule.packages # all wrappers
