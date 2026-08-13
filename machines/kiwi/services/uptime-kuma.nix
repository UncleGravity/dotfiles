_: let
  port = 3001;
in {
  services.uptime-kuma = {
    enable = true;
    settings.PORT = toString port;
  };

  services.newt.blueprint.proxy-resources.uptime-kuma = {
    name = "Uptime Kuma";
    protocol = "http";
    full-domain = "kuma.angel.pizza";
    auth = {
      sso-enabled = true;
      sso-roles = ["Member"];
    };
    targets = [
      {
        hostname = "localhost";
        method = "http";
        inherit port;
      }
    ];
  };
}
