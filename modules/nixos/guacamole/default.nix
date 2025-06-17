{ config, pkgs, lib, ... }:

{
  # Guacamole user-mapping.xml secret configuration
  # NOTE: This secret contains authentication configuration for Guacamole users
  sops.secrets."guacamole/user-mapping.xml" = {
    sopsFile = ./user-mapping.xml.sops;
    format = "binary";

    # IMPORTANT: Previously, without explicit user creation, we needed neededForUsers = true
    # because the guacamole service would create the user, but sops-nix ran before
    # that happened, causing a chicken-and-egg problem.
    #
    # Find with: systemctl show guacamole-server.service property=User --property=Group
    owner = "guacamole-server";
    group = "guacamole-server";
    mode = "0644";
  };

  # Explicitly create the guacamole-server user and group
  # This ensures they exist during sops-nix activation, allowing proper ownership
  # of secrets without needing neededForUsers = true
  users.users.guacamole-server = {
    isSystemUser = true;
    group = "guacamole-server";
  };
  users.groups.guacamole-server = {};

  # INFO: https://nixos.wiki/wiki/Remote_Desktop
  networking.firewall.allowedTCPPorts = [ 8080 ]; # Caddy needs this to access the web interface

  services.guacamole-server = {
    enable = true;
    host = "127.0.0.1";
    userMappingXml = config.sops.secrets."guacamole/user-mapping.xml".path;
  };

  services.guacamole-client = {
    enable = true;
    enableWebserver = true;
    settings = {
      guacd-port = 4822;
      guacd-hostname = "127.0.0.1";
    };
  };

  # Complain if RDP is not enabled.
  warnings = lib.mkIf (!config.my.displayManager.rdp.enable) [
    "my.displayManager.rdp.enable is false. xrdp (and therefore Guacamole) might not function as expected. Consider enabling displayManager.rdp for full functionality."
  ];
}