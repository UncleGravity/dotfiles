{ config, lib, pkgs, ... }:

{

  # ---------------------------------------------------------------------------
  # PODMAN CONFIG
  
  # Enable common container config files in /etc/containers
  # virtualisation.containers.enable = true;

  # virtualisation = {
  #   podman = {
  #     enable = true;

  #     # Create a `docker` alias for podman, to use it as a drop-in replacement
  #     dockerCompat = true;

  #     # Required for containers under podman-compose to be able to talk to each other.
  #     defaultNetwork.settings.dns_enabled = true;
  #   };
  # };

  # ---------------------------------------------------------------------------
  # DOCKER

  # Root Docker
  # virtualisation.docker.enable = true;
  # users.users.${username}.extraGroups = [ "docker" ];

  # Rootless Docker
  # Creates rootless docker service, can exist alongside root docker
  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true; # will force docker to use rootless context
  };

  # Enable docker service, rootless service not enabled by default
  systemd.user.services."docker".enable = true;
}