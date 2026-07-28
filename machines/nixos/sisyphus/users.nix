{
  config,
  username,
  ...
}: {
  sops.secrets."users/password-hash" = {
    sopsFile = ./secrets/secrets.yaml;
    neededForUsers = true;
  };

  users.users.${username}.hashedPasswordFile = config.sops.secrets."users/password-hash".path;
}
