{
  config,
  lib,
  pkgs,
  ...
}: {
  sops.secrets."ntfy/topic" = {}; # For NTFY notifications

  environment = {
    systemPackages = [pkgs.ntfy-sh];
    variables.NTFY_TOPIC = "$(cat ${config.sops.secrets."ntfy/topic".path})";
    shellAliases."ntfy" = "ntfy publish";
  };
}
