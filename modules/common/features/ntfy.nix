{
  config,
  lib,
  pkgs,
  username,
  ...
}: let
  cfg = config.my.ntfy;
in {
  # Requires the ntfy/topic secret from the repo-wide sops file; disable on
  # hosts that are not recipients of it (e.g. the Sparks).
  options.my.ntfy.enable =
    lib.mkEnableOption "ntfy shell notifications"
    // {default = true;};

  config = lib.mkIf cfg.enable {
    sops.secrets."ntfy/topic" = {
      owner = username;
      mode = "0400";
    }; # For NTFY notifications

    environment = {
      systemPackages = [pkgs.ntfy-sh];
      variables.NTFY_TOPIC = "$(cat ${config.sops.secrets."ntfy/topic".path})";
      shellAliases."ntfy" = "ntfy publish";
    };
  };
}
