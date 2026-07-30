# Automatically upload locally built Nix store paths to Cachix.
{
  config,
  pkgs,
  ...
}: {
  sops.secrets."cachix/auth-token" = {
    sopsFile = ../../secrets/cachix.yaml;
    mode = "0400";
  };

  launchd.daemons.cachix-watch-store = {
    path = [config.nix.package];
    script = ''
      export CACHIX_AUTH_TOKEN="$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."cachix/auth-token".path})"
      exec ${pkgs.cachix}/bin/cachix watch-store unclegravity-nix
    '';
    serviceConfig = {
      KeepAlive = true;
      RunAtLoad = true;
      ProcessType = "Background";
    };
  };
}
