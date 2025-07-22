{
  config,
  lib,
  pkgs,
  username,
  ...
}: {
  sops.secrets."ntfy/topic" = {
    owner = username;
    mode = "0400";
  }; # For NTFY notifications

  environment = {
    systemPackages = [pkgs.ntfy-sh];
    variables.NTFY_TOPIC = "$(cat ${config.sops.secrets."ntfy/topic".path})";
    shellAliases."ntfy" = "ntfy publish";
  };
}
