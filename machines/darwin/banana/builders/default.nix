{
  imports = [
    ./nixbuild.nix
    # ./nix-linux-builder.nix
    # ./virby.nix
  ];

  nix = {
    distributedBuilds = true;
    settings.builders-use-substitutes = true;
  };
}
