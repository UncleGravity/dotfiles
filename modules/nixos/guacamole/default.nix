{ config, pkgs, lib, ... }:
let
  cfg = config.my.guacamole;
in
{
  options.my.guacamole = {
    enable = lib.mkEnableOption "Guacamole remote desktop gateway";
    
    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Host address for guacamole server";
    };
    
    clientPort = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port for the Guacamole web interface";
    };
    
    serverPort = lib.mkOption {
      type = lib.types.port;
      default = 4822;
      description = "Port for the Guacamole daemon";
    };
  };

  config = lib.mkIf cfg.enable {
    # Only enable on supported platforms
    assertions = [
      {
        assertion = lib.elem pkgs.stdenv.hostPlatform.system [ "x86_64-linux" "i686-linux" ];
        message = "Guacamole is only supported on x86_64-linux and i686-linux platforms";
      }
    ];

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
    networking.firewall.allowedTCPPorts = [ cfg.clientPort ]; # Caddy needs this to access the web interface

    services.guacamole-server = {
      enable = true;
      host = cfg.host;
      port = cfg.serverPort;
      userMappingXml = config.sops.secrets."guacamole/user-mapping.xml".path;
    };

    services.guacamole-client = {
      enable = true;
      enableWebserver = true;
      settings = {
        guacd-port = cfg.serverPort;
        guacd-hostname = cfg.host;
      };
    };

    # Complain if RDP is not enabled.
    warnings = lib.mkIf (!config.my.displayManager.rdp.enable) [
      "my.displayManager.rdp.enable is false. xrdp (and therefore Guacamole) might not function as expected. Consider enabling displayManager.rdp for full functionality."
    ];
  };
}