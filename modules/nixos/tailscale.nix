{ config, lib, pkgs, ... }:
let
  cfg = config.my.tailscale;
in
{
  options.my.tailscale = {
    enable = lib.mkEnableOption "Tailscale VPN with exit node and subnet routing";
    
    advertiseRoutes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "192.168.1.0/24" ];
      description = "Subnets to advertise to the tailnet";
    };
    
    enableExitNode = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to advertise this machine as an exit node";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.tailscale ];
    networking.firewall.trustedInterfaces = [ "tailscale0" ];

    sops.secrets."tailscale/authkey" = {
      mode = "0600"; # Only root can read the auth key
      owner = "root";
    };

    services.tailscale = {
      enable             = true;
      authKeyFile        = config.sops.secrets."tailscale/authkey".path;  
      openFirewall       = true;            # allow the Tailscale UDP port through the firewall
      useRoutingFeatures = "both";          # enable subnet-router & exit-node roles 
      extraUpFlags       = [
        "--reset"                           # reset unspecified settings to default values.
      ] ++ lib.optionals cfg.enableExitNode [
        "--advertise-exit-node"
      ];
      extraSetFlags = lib.optionals (cfg.advertiseRoutes != []) [
        "--advertise-routes=${lib.concatStringsSep "," cfg.advertiseRoutes}"
      ];
    };
  };
}
