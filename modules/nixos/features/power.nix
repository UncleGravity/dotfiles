{
  config,
  lib,
  ...
}: {
  options.my.power.alwaysOn = lib.mkEnableOption "an always-on host that must not suspend or hibernate";

  config = lib.mkIf config.my.power.alwaysOn {
    systemd.targets = {
      sleep.enable = false;
      suspend.enable = false;
      hibernate.enable = false;
      hybrid-sleep.enable = false;
    };

    systemd.sleep.settings.Sleep = {
      AllowSuspend = "no";
      AllowHibernation = "no";
      AllowHybridSleep = "no";
      AllowSuspendThenHibernate = "no";
    };
  };
}
