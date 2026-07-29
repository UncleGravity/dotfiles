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
    ntfy.enable = false;
  };

  services.dgx-dashboard.enable = lib.mkForce node.controller;

  environment.systemPackages = with pkgs; [
    git
    jq
    rsync
    tmux
  ];
}
