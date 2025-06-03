{ config, pkgs, lib, username, ... }:
let
  cfg = config.services.immich;
in
{
  # ---------------------------------------------------------------------------
  
  # Add your user and immich to the nas group
  users.users.${username}.extraGroups = [ "share" "video" "render" ];
  users.users.immich.extraGroups = [ "share" ];

  # ---------------------------------------------------------------------------
  # Immich Service Configuration
  services.immich = {
    enable = true;
    host = "0.0.0.0"; # Listen on all interfaces (IPv4 and IPv6)
    group = "nas";
    port = 2283;
    openFirewall = true;
    mediaLocation = "/nas/media";
    # Hardware acceleration for video transcoding
    accelerationDevices = null; # Give access to all devices
  };

  # Ensure /nas/media has correct permissions for the nas group
  systemd.tmpfiles.rules = [
    "d /nas/media 0775 immich nas - -"  # Owned by immich, group nas, group-writable
  ];
}