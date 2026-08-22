{
  config,
  pkgs,
  ...
}: {
  systemd.services.cron-cachix-fix-check = {
    description = "Check whether nixos-unstable includes the Cachix trusted-key fix";
    wants = ["network-online.target"];
    after = ["network-online.target"];
    path = [
      config.my.ntfy.package
      pkgs.nix
      pkgs.ripgrep
    ];

    serviceConfig.Type = "oneshot";

    script = ''
      ${pkgs.bash}/bin/bash ${./check-cachix-fix.sh}
    '';
  };

  systemd.timers.cron-cachix-fix-check = {
    description = "Check daily for the Cachix trusted-key fix";
    wantedBy = ["timers.target"];

    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };
}
