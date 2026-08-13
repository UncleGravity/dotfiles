{
  config,
  pkgs,
  username,
  ...
}: {
  clan.core.vars.generators."console-password-${username}" = {
    prompts.password = {
      description = "Console password for ${username}";
      type = "hidden";
      persist = false;
    };

    files.password-hash.neededFor = "users";
    runtimeInputs = [pkgs.mkpasswd];

    script = ''
      if [[ ! -s "$prompts/password" ]]; then
        echo "Console password must not be empty" >&2
        exit 1
      fi

      mkpasswd -s < "$prompts/password" | tr -d "\n" > "$out/password-hash"
    '';
  };

  # Emergency entrance: Only works from Hetzner web console. Not SSH.
  users.users.${username}.hashedPasswordFile =
    config.clan.core.vars.generators."console-password-${username}".files.password-hash.path;
}
