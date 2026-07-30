# Automatically upload locally built Nix store paths to Cachix.
{config, ...}: {
  sops.secrets."cachix/auth-token" = {
    sopsFile = ../../secrets/cachix.yaml;
    mode = "0400";
  };

  services.cachix-watch-store = {
    enable = true;
    cacheName = "unclegravity-nix";
    cachixTokenFile = config.sops.secrets."cachix/auth-token".path;
  };
}
