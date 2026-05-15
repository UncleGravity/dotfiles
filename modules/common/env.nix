{
  config,
  lib,
  username,
  ...
}: let
  cfg = config.my.env;
  home = config.users.users.${username}.home;

  mkShellSecret = name: {
    path = "${home}/.config/zsh/secrets/${name}.sh";
    owner = username;
    mode = "0600";
  };
in {
  # ---------------------------------------------------------------------------
  # Shell env secrets (sourced from modules/home/zsh).
  #
  # Each shell file is opt-in per machine so policy is explicit. `home` is on
  # by default (every machine wants personal env); `work` is off by default
  # and must be enabled on hosts trusted with work credentials.
  # ---------------------------------------------------------------------------
  options.my.env = {
    home.enable =
      lib.mkEnableOption "personal shell env secrets (~/.config/zsh/secrets/home.sh)"
      // {default = true;};
    work.enable = lib.mkEnableOption "work shell env secrets (~/.config/zsh/secrets/work.sh)";
  };

  config.sops.secrets = lib.mkMerge [
    (lib.mkIf cfg.home.enable {"home.sh" = mkShellSecret "home";})
    (lib.mkIf cfg.work.enable {"work.sh" = mkShellSecret "work";})
  ];
}
