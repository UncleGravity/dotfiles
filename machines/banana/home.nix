{
  inputs,
  pkgs,
  ...
}: let
  localPackages = inputs.self.packages.${pkgs.stdenv.hostPlatform.system};
in {
  # banana-specific home overrides go here
  home.stateVersion = "25.05";

  my.home.development.enable = true;

  home.packages = [
    localPackages.clan
    localPackages.vm
  ];
}
