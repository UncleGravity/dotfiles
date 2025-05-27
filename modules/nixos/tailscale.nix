{ config, ... }:

{
  sops.secrets."tailscale/authkey" = {
    mode = "0600"; # Only root can read the auth key
  };

  services.tailscale = {
    enable             = true;
    authKeyFile        = config.sops.secrets."tailscale/authkey".path;  
    openFirewall       = true;              # allow the Tailscale UDP port through the firewall
    # useRoutingFeatures = "both";          # enable subnet-router & exit-node roles 
    # extraUpFlags       = [
    #   "--advertise-exit-node"             # if you want this server to be an exit node
    #   "--accept-routes"                   # if you want it to accept subnet routes
    # ];
  };

  # Let your firewall trust the tailscale0 interface
  networking.firewall.trustedInterfaces = [ "tailscale0" ];  
}
