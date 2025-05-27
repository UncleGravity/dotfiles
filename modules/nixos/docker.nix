{ config, lib, pkgs, username, ... }:

{
  # ---------------------------------------------------------------------------
  # DOCKER
  # Root and Rootless can coexist, select which one by running docker with or without sudo

  # ---------------------------------------------------------------------------
  # Allow docker to access the network (to avoid port forwarding manually... I think)
  networking.firewall.trustedInterfaces = [ "docker0" ];

  # ---------------------------------------------------------------------------
  # Root Docker
  virtualisation.docker.enable = true;
  users.users.${username}.extraGroups = [ "docker" ];

  # ---------------------------------------------------------------------------
  # Rootless Docker
  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true; # will force docker to use rootless context
  };

  # Enable rootless docker service, it's not enabled by default
  systemd.user.services."docker".enable = true;

  # Rootless Docker won't have permission to use ports below 1024 by default
  boot.kernel.sysctl = {
    "net.ipv4.ip_unprivileged_port_start" = 80;
  };
}
