# Automatically upload locally built Nix store paths to Cachix.
{config, ...}: let
  authToken = config.clan.core.vars.generators.cachix.files.auth-token;
in {
  clan.core.vars.generators.cachix.files.auth-token.restartUnits = [
    "cachix-watch-store-agent.service"
  ];

  services.cachix-watch-store = {
    enable = true;
    cacheName = "unclegravity-nix";
    cachixTokenFile = authToken.path;
  };
}
