{
  config,
  username,
  ...
}: {
  sops.secrets."copyparty/password" = {
    sopsFile = ../secrets/secrets.yaml;
    owner = username;
    group = "users";
    mode = "0400";
    restartUnits = ["copyparty.service"];
  };

  services.copyparty = {
    enable = true;
    user = username;
    group = "users";

    accounts.${username}.passwordFile =
      config.sops.secrets."copyparty/password".path;

    settings = {
      i = "0.0.0.0"; # careful!
      p = 3923;
      http-only = true;
      no-reload = true;
      hist = "/var/cache/copyparty";
    };

    volumes = {
      "/kiwi" = {
        path = "/srv/share";
        access.r = username;
      };

      "/unas" = {
        path = "/mnt/nas/unas";
        access.r = username;
      };
    };
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
