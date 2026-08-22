{
  config,
  lib,
  pkgs,
  username,
  ...
}: let
  cfg = config.my.ntfy;
  topicFile = config.clan.core.vars.generators.ntfy.files.topic.path;

  ntfy = pkgs.writeShellApplication {
    name = "ntfy";
    text = ''
      NTFY_TOPIC="$(< ${lib.escapeShellArg topicFile})"
      export NTFY_TOPIC
      exec ${lib.getExe pkgs.ntfy-sh} "$@"
    '';
  };
in {
  options.my.ntfy = {
    enable =
      lib.mkEnableOption "ntfy shell notifications"
      // {default = true;};

    package = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      description = "ntfy client configured with the generated topic";
    };
  };

  config = lib.mkIf cfg.enable {
    my.ntfy.package = ntfy;

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

    environment.systemPackages = [cfg.package];
  };
}
