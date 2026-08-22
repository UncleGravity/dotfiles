{pkgs, ...}: {
  systemd.services.cron-hello-world = {
    description = "Print hello-world";

    serviceConfig.Type = "oneshot";

    script = ''
      ${pkgs.coreutils}/bin/printf '%s\n' hello-world
    '';
  };

  systemd.timers.cron-hello-world = {
    description = "Print hello-world hourly";
    wantedBy = ["timers.target"];

    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
    };
  };
}
