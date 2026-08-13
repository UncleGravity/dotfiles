{
  inputs,
  pkgs,
  ...
}: let
  localPackages = inputs.self.packages.${pkgs.stdenv.hostPlatform.system};
in {
  # banana-specific home overrides go here
  my.home.development.enable = true;

  home.packages = [
    localPackages.clan
    localPackages.vm
  ];
}
