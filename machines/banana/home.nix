{
  inputs,
  pkgs,
  ...
}: {
  # banana-specific home overrides go here
  my.home.development.enable = true;

  home.packages = [
    inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.vm
  ];
}
