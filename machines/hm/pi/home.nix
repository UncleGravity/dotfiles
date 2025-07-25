{
  config,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    "${inputs.self}/modules/home/_core.nix"
  ];

  # More stuff here...
}
