{config, ...}: {
  sops.secrets."tailscale/authkey" = {
    mode = "0600";
    owner = "root";
  };

  my.tailscale = {
    enable = true;
    authKeyFile = config.sops.secrets."tailscale/authkey".path;
    advertiseRoutes = [];
    enableExitNode = false;
  };
}
