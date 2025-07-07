{ config, pkgs, lib, username, ... }:
let
  cfg = config.my.immich;
in
{
  options.my.immich = {
    enable = lib.mkEnableOption "Immich photo and video management";
    
    mediaLocation = lib.mkOption {
      type = lib.types.str;
      default = "/nas/media";
      description = "Path to store media files";
    };
    
    port = lib.mkOption {
      type = lib.types.port;
      default = 2283;
      description = "Port for Immich web interface";
    };
    
    host = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "Host address to bind to";
    };
  };

  config = lib.mkIf cfg.enable {
    # Create the nas group
    users.groups.nas = {};
    
    # Add your user and immich to the nas group
    users.users.${username}.extraGroups = [ "share" "video" "render" ];
    users.users.immich.extraGroups = [ "share" ];

    # Immich Service Configuration
    services.immich = {
      enable = true;
      host = cfg.host;
      group = "nas";
      port = cfg.port;
      openFirewall = true;
      mediaLocation = cfg.mediaLocation;
      # Hardware acceleration for video transcoding
      accelerationDevices = null; # Give access to all devices
    };

    # Ensure media location has correct permissions for the nas group
    systemd.tmpfiles.rules = [
      "d ${cfg.mediaLocation} 0775 immich nas - -"  # Owned by immich, group nas, group-writable
    ];
  };
}