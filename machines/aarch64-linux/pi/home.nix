{
  config,
  pkgs,
  inputs,
  self,
  ...
}: {
  imports = [
    "${self}/modules/home/_core.nix"
  ];

  nixpkgs.config.allowUnfree = true;

  # More stuff here...
}
