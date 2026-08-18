{
  config,
  username,
  ...
}: let
  domain = "files.angel.pizza";
  port = 3923;
in {
  clan.core.vars.generators.copyparty = {
    prompts.password = {
      description = "Copyparty password for ${username}";
      type = "hidden";
      persist = true;
    };
    files.password = {
      owner = username;
      group = "users";
      mode = "0400";
      restartUnits = ["copyparty.service"];
    };
    script = ''
      if [[ ! -s "$out/password" ]]; then
        echo "Copyparty password must not be empty" >&2
        exit 1
      fi

      originalSize="$(wc -c < "$out/password")"
      singleLineSize="$(tr -d '\r\n' < "$out/password" | wc -c)"
      if [[ "$originalSize" -ne "$singleLineSize" ]]; then
        echo "Copyparty password must be a single line" >&2
        exit 1
      fi
    '';
  };

  services.copyparty = {
    enable = true;
    user = username;
    group = "users";

    # accounts.${username}.passwordFile =
    #   config.clan.core.vars.generators.copyparty.files.password.path;

    settings = {
      p = port;
      http-only = true;
      no-reload = true;
      hist = "/var/cache/copyparty";
      idp-h-usr = "remote-user";
      xff-src = "127.0.0.1";
    };

    volumes = {
      "/kiwi" = {
        path = "/srv/share";
        access.r = "*";
      };

      "/unas" = {
        path = "/mnt/nas/unas";
        access.r = "*";
      };
    };
  };

  services.newt.blueprint.proxy-resources.copyparty = {
    name = "Copyparty";
    protocol = "http";
    full-domain = domain;
    auth.sso-enabled = true;
    auth.sso-users = [config.services.tinyauth.settings.AUTH_USERATTRIBUTES_ANGEL_EMAIL];
    targets = [
      {
        hostname = "127.0.0.1";
        method = "http";
        inherit port;
      }
    ];
  };

  systemd.services.copyparty = {
    wants = [
      "network-online.target"
      "remote-fs.target"
    ];
    after = [
      "network-online.target"
      "remote-fs.target"
    ];
    unitConfig.RequiresMountsFor = ["/srv/share"];
  };
}
