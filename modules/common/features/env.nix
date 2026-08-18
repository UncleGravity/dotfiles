{
  config,
  lib,
  pkgs,
  username,
  ...
}: let
  cfg = config.my.env;

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
      lib.mkEnableOption "personal shell environment secrets"
      // {default = true;};
    work.enable = lib.mkEnableOption "work shell environment secrets";
  };

  config.clan.core.vars.generators = lib.mkMerge [
    (lib.mkIf cfg.home.enable {shell-env-home = mkShellGenerator "home";})
    (lib.mkIf cfg.work.enable {shell-env-work = mkShellGenerator "work";})
  ];
}
