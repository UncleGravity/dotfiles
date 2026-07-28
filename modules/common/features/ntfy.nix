{
  config,
  lib,
  pkgs,
  username,
  ...
}: let
  cfg = config.my.ntfy;
in {
  options.my.ntfy.enable =
    lib.mkEnableOption "ntfy shell notifications"
    // {default = true;};

  config = lib.mkIf cfg.enable {
    sops.secrets."ntfy/topic" = {
      sopsFile = ../../../secrets/ntfy.yaml;
      owner = username;
      mode = "0400";
    };

    environment = {
      systemPackages = [pkgs.ntfy-sh];
      shellAliases."ntfy" = ''NTFY_TOPIC="$(cat ${config.sops.secrets."ntfy/topic".path})" ntfy publish'';
    };
  };
}
