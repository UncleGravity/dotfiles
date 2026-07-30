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
      i = "0.0.0.0";
      p = 3923;
      http-only = true;
      no-reload = true;
      hist = "/var/cache/copyparty";
    };

    volumes = {
      "/kiwi" = {
        path = "/nas";
        access.r = username;
      };

      "/unas" = {
        path = "/mnt/nas/unas";
        access.r = username;
      };
    };
  };

  systemd.services.copyparty = {
    wants = ["network-online.target"];
    after = ["network-online.target"];
    unitConfig.RequiresMountsFor = [
      "/nas"
      "/mnt/nas/unas/ai"
      "/mnt/nas/unas/personal"
    ];
  };
}
