{
  inputs,
  username,
  ...
}: {
  home-manager = {
    extraSpecialArgs = {inherit inputs username;};
    sharedModules = [../home];
    useGlobalPkgs = true;
    useUserPackages = true;
  };
}
