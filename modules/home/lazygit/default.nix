{
  inputs,
  pkgs,
  ...
}: let
  lazygit = inputs.wrapper-manager.lib.wrapWith pkgs {
    basePackage = pkgs.lazygit;
    appendFlags = ["-ucf" ./config.yml];
    pathAdd = [
      pkgs.delta
    ];
  };
in {
  home.packages = [lazygit];
}
