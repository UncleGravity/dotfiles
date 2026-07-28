{
  config,
  username,
  ...
}: {
  # Console login only (SSH is key-only, sudo is passwordless).
  sops.secrets."users/password-hash" = {
    sopsFile = ./secrets/shared.yaml;
    neededForUsers = true;
  };

  users.users.${username}.hashedPasswordFile = config.sops.secrets."users/password-hash".path;
}
