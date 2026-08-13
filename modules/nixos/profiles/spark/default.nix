{
  config,
  lib,
  pkgs,
  ...
}: let
  cluster = config.my.sparkCluster;
in {
  imports = [
    ./hardware
    ./inference
    ./monitoring.nix
    ./networking
  ];

  my = {
    profile = "server";
    env.home.enable = false;
    unas.ai.enable = true;
    ntfy.enable = false;
  };

  services.dgx-dashboard.enable = lib.mkForce cluster.isController;

  nix.settings = {
    extra-substituters = ["https://graham33.cachix.org"];
    extra-trusted-public-keys = ["graham33.cachix.org-1:DqH72VpwSrACa3+L9eqh4bixjWx9IQUaxQtRh4gtkX8="];
  };

  environment.systemPackages = with pkgs; [
    git
    jq
    rsync
    tmux
  ];
}
