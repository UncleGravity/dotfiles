{
  inputs,
  username,
  ...
}: {
  home-manager = {
    extraSpecialArgs = {inherit inputs username;};
    sharedModules = [
      inputs.multiverse.homeManagerModules.default
      ../home
    ];
    useGlobalPkgs = true;
    useUserPackages = true;
  };
}
