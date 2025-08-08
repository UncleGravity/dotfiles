{
  inputs,
  pkgs,
  system,
  wrapper-manager,
  lib,
  ...
}: let
  # Define all packages
  allPackages = {
    vm = pkgs.callPackage ./vm.nix {inherit pkgs;};
    greet = pkgs.callPackage ./greet.nix {inherit pkgs;};
    bootstrap = pkgs.callPackage ./bootstrap.nix {inherit pkgs;};
    # optnix = pkgs.callPackage ./optnix.nix {inherit inputs pkgs lib;};
    # optnix-fzf = pkgs.callPackage ./optnix-fzf.nix {inherit inputs pkgs lib;};
    nix-search-fzf = pkgs.callPackage ./nix-search-fzf.nix {inherit inputs pkgs lib;};
    push = pkgs.callPackage ./push.nix {inherit pkgs lib;};
    decrypt = pkgs.callPackage ./decrypt.nix {inherit pkgs lib;};
    encrypt = pkgs.callPackage ./encrypt.nix {inherit pkgs lib;};
    t = pkgs.callPackage ./t.nix {inherit pkgs lib;};
    nvim-clean = pkgs.callPackage ./nvim-clean {inherit pkgs;};
  };


  # Halt. Everything below this line is boilerplate.
  # -------------------------------------------------------------------------------------
  # -------------------------------------------------------------------------------------
  # -------------------------------------------------------------------------------------
  # -------------------------------------------------------------------------------------

  # Filter packages that support current system
  individualPackages =
    lib.filterAttrs (
      name: pkg:
        builtins.elem system (pkg.meta.platforms or lib.platforms.all)
    )
    allPackages;

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
in
  {
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
