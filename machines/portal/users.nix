{
  config,
  username,
  ...
}: {
  clan.core.vars.generators."console-password-${username}" = {
    files.password-hash.neededFor = "users";
    script = ''
      echo "Set console-password-${username}/password-hash with 'clan vars set'" >&2
      exit 1
    '';
  };

  # Emergency entrance: Only works from Hetzner web console. Not SSH.
  users.users.${username}.hashedPasswordFile =
    config.clan.core.vars.generators."console-password-${username}".files.password-hash.path;
}
