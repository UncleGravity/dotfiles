{
  config,
  lib,
  options,
  pkgs,
  username,
  ...
}: let
  cfg = config.my.env;
  home = config.users.users.${username}.home;

  mkShellGenerator = name: {
    share = true;

    prompts."${name}.sh" = {
      description = "Contents of ${name}.sh";
      type = "multiline-hidden";
      persist = true;
    };

    files."${name}.sh" = {
      owner = username;
      group =
        if pkgs.stdenv.hostPlatform.isDarwin
        then "staff"
        else "users";
      mode = "0600";
    };

    script = ''
      if [[ ! -s "$out/${name}.sh" ]]; then
        echo "${name}.sh must not be empty" >&2
        exit 1
      fi
    '';
  };

  mkShellSecret = name: {
    "vars/shell-env-${name}/${name}.sh".path = "${home}/.config/zsh/secrets/${name}.sh";
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
      clan.core.vars.generators = lib.mkMerge [
        (lib.mkIf cfg.home.enable {shell-env-home = mkShellGenerator "home";})
        (lib.mkIf cfg.work.enable {shell-env-work = mkShellGenerator "work";})
      ];

      sops.secrets = lib.mkMerge [
        (lib.mkIf cfg.home.enable (mkShellSecret "home"))
        (lib.mkIf cfg.work.enable (mkShellSecret "work"))
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
