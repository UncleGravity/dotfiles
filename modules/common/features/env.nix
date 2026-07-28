{
  config,
  lib,
  options,
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
  # Shell env secrets (explicitly sourced in zshrc).
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

  config = lib.mkMerge [
    {
      sops.secrets = lib.mkMerge [
        (lib.mkIf cfg.home.enable {"home.sh" = mkShellSecret "home";})
        (lib.mkIf cfg.work.enable {"work.sh" = mkShellSecret "work";})
      ];
    }

    (lib.optionalAttrs (options ? systemd.tmpfiles.rules) {
      # sops-nix creates the missing parent directories as root (bad).
      systemd.tmpfiles.rules = lib.mkIf (cfg.home.enable || cfg.work.enable) [
        "d ${home}/.config 0700 ${username} users -"
        "d ${home}/.config/zsh 0700 ${username} users -"
        "d ${home}/.config/zsh/secrets 0700 ${username} users -"
      ];
    })
  ];
}
