{
  lib,
  node,
  pkgs,
  ...
}: {
  imports = [
    ./hardware
    ./inference
    ./networking
    ./users.nix
  ];

  my = {
    profile = "server";
    env.home.enable = false;
    nas = {
      kiwi.enable = true;
      unas.ai.enable = true;
    };
    ntfy.enable = false;
  };

  services.dgx-dashboard.enable = lib.mkForce node.controller;

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
