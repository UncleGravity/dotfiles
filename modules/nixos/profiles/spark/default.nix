{
  config,
  inputs,
  lib,
  pkgs,
  username,
  ...
}: let
  cluster = config.my.sparkCluster;
in {
  imports = [
    ../..
    inputs.self.nixosModules.inference
    inputs.dgx-spark.nixosModules.dgx-spark
    ./hardware
    ./inference
    ./monitoring.nix
    ./networking
  ];

  nixpkgs.hostPlatform = "aarch64-linux";
  system.stateVersion = "26.05";

  home-manager.users.${username}.imports = [../../../home/profiles/spark.nix];

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
