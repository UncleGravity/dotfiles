{
  config,
  lib,
  ...
}: {
  config = lib.mkIf config.my.profiles.server.enable {
    # ---------------------------------------------------------------------------
    # Disable sleep, suspend, hibernate, and hybrid-sleep
    # This is necessary because the GNOME3/GDM auto-suspend feature cannot be disabled in GUI!
    # If no user is logged in, the machine will power down after 20 minutes.
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
