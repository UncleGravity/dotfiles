# Automatically upload locally built Nix store paths to Cachix.
{
  config,
  lib,
  pkgs,
  ...
}: let
  authToken = config.clan.core.vars.generators.cachix.files.auth-token;
in {
  launchd.daemons.cachix-watch-store = {
    path = [config.nix.package];
    script = ''
      export CACHIX_AUTH_TOKEN="$(${pkgs.coreutils}/bin/cat ${authToken.path})"
      exec ${pkgs.cachix}/bin/cachix watch-store unclegravity-nix
    '';
    serviceConfig = {
      KeepAlive = true;
      RunAtLoad = true;
      ProcessType = "Background";
    };
  };

  system.activationScripts.postActivation.text = lib.mkOrder 1600 ''
    label=${lib.escapeShellArg config.launchd.daemons.cachix-watch-store.serviceConfig.Label}
    if /bin/launchctl print "system/$label" >/dev/null 2>&1; then
      /bin/launchctl kickstart -k "system/$label"
    fi
  '';
}
