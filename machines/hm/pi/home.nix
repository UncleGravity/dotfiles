{
  config,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    "${inputs.self}/modules/home/_core.nix"
  ];

  nixpkgs.config.allowUnfree = true;

  # More stuff here...
}
