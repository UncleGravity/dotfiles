{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: let
  # Wrapper
  tv = inputs.wrapper-manager.lib.wrapWith pkgs {
    basePackage = pkgs.television;
    prependFlags = [
      "--config-file"
      ./config.toml
      "--cable-dir"
      ./cable
    ];
  };

  # Alias
  tt = pkgs.writeShellApplication {
    name = "tt";
    runtimeInputs = [tv pkgs.fzf pkgs.findutils];
    text = ''
      ${lib.getExe tv} list-channels | fzf --no-multi | xargs -r tv
    '';
  };
in {
  programs.television = {
    enable = true;
    # package = inputs.television.packages.${pkgs.system}.default;
    package = tv;
    enableZshIntegration = false;
  };

  home.packages = [tt];
}
