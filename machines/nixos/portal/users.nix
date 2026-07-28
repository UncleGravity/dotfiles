{
  config,
  username,
  ...
}: {
  sops.secrets."users/password-hash" = {
    sopsFile = ./secrets/secrets.yaml;
    neededForUsers = true;
  };

  # Emergency entrance: Only works from Hetzner web console. Not SSH.
  users.users.${username}.hashedPasswordFile = config.sops.secrets."users/password-hash".path;
}
