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
    clan.core.vars.generators.ntfy = {
      share = true;

      prompts.topic = {
        description = "ntfy topic";
        type = "hidden";
        persist = true;
      };

      files.topic = {
        owner = username;
        mode = "0400";
      };
    };

    environment = {
      systemPackages = [pkgs.ntfy-sh];
      shellAliases."ntfy" = ''NTFY_TOPIC="$(cat ${config.clan.core.vars.generators.ntfy.files.topic.path})" ntfy publish'';
    };
  };
}
