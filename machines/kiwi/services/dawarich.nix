{config, ...}: let
  domain = "dawarich.angel.pizza";
  port = 3002;
  oidcClientId = "19ca6a2e-1dd9-4b02-b4f4-3b8520cd878e";
in {
  sops.templates."dawarich.env" = {
    content = ''
      OIDC_CLIENT_SECRET=${config.sops.placeholder."tinyauth/oidc/dawarich-client-secret"}
    '';
    owner = "dawarich";
    group = "dawarich";
    mode = "0400";
    restartUnits = [
      "dawarich-sidekiq-all.service"
      "dawarich-web.service"
    ];
  };

  services = {
    dawarich = {
      enable = true;
      localDomain = domain;
      webPort = port;
      configureNginx = false;
      extraEnvFiles = [config.sops.templates."dawarich.env".path];

      environment = {
        ALLOW_EMAIL_PASSWORD_LOGIN = "true";
        ALLOW_EMAIL_PASSWORD_REGISTRATION = "false";
        APPLICATION_PROTOCOL = "https";
        DISTANCE_UNIT = "mi";
        OIDC_AUTO_REGISTER = "true";
        OIDC_CLIENT_ID = oidcClientId;
        OIDC_ISSUER = "https://auth.angel.pizza";
        OIDC_PROVIDER_NAME = "TinyAuth";
        OIDC_REDIRECT_URI = "https://${domain}/users/auth/openid_connect/callback";
        STORE_GEODATA = "false";
      };
    };

    newt.blueprint.proxy-resources.dawarich = {
      name = "Dawarich";
      protocol = "http";
      full-domain = domain;
      auth.sso-enabled = false;
      targets = [
        {
          hostname = "127.0.0.1";
          method = "http";
          inherit port;
        }
      ];
    };
  };
}
