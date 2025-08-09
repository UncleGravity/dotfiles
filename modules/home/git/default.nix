{
  inputs,
  pkgs,
  ...
}: let
  git = inputs.wrapper-manager.lib.wrapWith pkgs {
    basePackage = pkgs.git;
    env.GIT_CONFIG_GLOBAL.value = ./config;
    pathAdd = [
      pkgs.delta # Better diff viewer (configured in git config)
      pkgs.openssh # SSH for remote repositories
      pkgs.coreutils # Essential utilities (cp, mv, etc.) used by git
      pkgs.git-lfs # Large File Storage support
    ];
  };
in {
  home.packages = [git];
}
