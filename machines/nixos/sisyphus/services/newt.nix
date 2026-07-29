{config, ...}: {
  sops.secrets = {
    "newt/id".sopsFile = ../secrets/secrets.yaml;
    "newt/password".sopsFile = ../secrets/secrets.yaml;
    "newt/secret".sopsFile = ../secrets/secrets.yaml;
  };
  sops.templates."newt.env".content = ''
    NEWT_ID=${config.sops.placeholder."newt/id"}
    AI_PASSWORD=${config.sops.placeholder."newt/password"}
    NEWT_SECRET=${config.sops.placeholder."newt/secret"}
  '';

  services.newt = {
    enable = true;
    settings.endpoint = "https://pangolin.angel.pizza";
    environmentFile = config.sops.templates."newt.env".path;
  };
}
