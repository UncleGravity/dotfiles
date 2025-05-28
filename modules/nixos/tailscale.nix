{ config, pkgs, ... }:

{

  environment.systemPackages = [ pkgs.tailscale ];
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  sops.secrets."tailscale/authkey" = {
    mode = "0600"; # Only root can read the auth key
  };

  services.tailscale = {
    enable             = true;
    authKeyFile        = config.sops.secrets."tailscale/authkey".path;  
    openFirewall       = true;            # allow the Tailscale UDP port through the firewall
    useRoutingFeatures = "both";          # enable subnet-router & exit-node roles 
    extraUpFlags       = [
      "--advertise-exit-node"
      "--reset"                           # reset unspecified settings to default values.
    ];
    extraSetFlags = [
      "--advertise-routes=192.168.1.0/24"
    ];
  };  
}
