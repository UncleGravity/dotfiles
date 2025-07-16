{
  self,
  inputs,
  systemStateVersion,
  ...
}: {
  imports = [
    ./disko.nix # Disko auto-generates fileSystems entries (originally managed in hardware.nix)
    ./hardware.nix
    ./mounts.nix
    ./zfs.nix
    ./backup
    ./samba.nix
    # ./wifi.nix
    "${self}/modules/nixos/_core.nix"
  ];

  # ---------------------------------------------------------------------------
  # Enable server-specific modules
  my.displayManager = {
    enable = true;
    desktop = "gnome";
    rdp.enable = true; # For Guacamole
  };

  # Enable server services (beyond the defaults from _core.nix)
  my.guacamole.enable = true; # Remote desktop gateway
  # my.grafana.enable = true;      # TODO: Modularize grafana.nix
  # Note: samba.nix is imported directly above (machine-specific)

  services.iperf3 = {
    enable = true;
    openFirewall = true; # tcp/udp = [ 5201 ]
  };

  networking.networkmanager.settings = {
    "connection"."wifi.powersave" = 2; # 2 = disabled
  };

  networking.firewall.allowedTCPPorts = [19999]; # netdata #TODO: Remove this

  # services.udisks2.enable = true; # Auto-mount external drives
  # services.udiskie.enable = true;
  # services.devmon.enable = true;

  # my.restic = {
  #   enable = true;
  #   local = {
  #     enable = true;
  #     zfsDatasets = [ "storagepool/root" ]; # Will take a snapshot, back up, then delete it
  #     paths = [ "/home" "/var/log" ];
  #     timerConfig.OnCalendar = "daily 02:00";
  #     pruneOpts = [
  #       "--keep-daily 7"
  #       "--keep-weekly 5"
  #       "--keep-monthly 12"
  #     ];
  #     stats = true;
  #     healthCheck = {
  #       enable = true;
  #       url = "https://example.com/health-local";
  #     };
  #     alerts = {
  #       enable = true;
  #       url = "https://example.com/alerts";
  #     };
  #   };

  #   remote = {
  #     enable = true;
  #     zfsDatasets = [ "storagepool/root" ]; # Will take a snapshot, back up, then delete it
  #     paths = [ "/home" "/var/log" ];
  #     timerConfig.OnCalendar = "daily 03:00";
  #     pruneOpts = [
  #       "--keep-daily 7"
  #       "--keep-weekly 5"
  #       "--keep-monthly 12"
  #     ];
  #     stats = true;
  #     healthCheck = {
  #       enable = true;
  #       url = "https://example.com/health-remote";
  #     };
  #     alerts = {
  #       enable = true;
  #       url = "https://example.com/alerts";
  #     };
  #   };
  # };

  # ---------------------------------------------------------------------------
  # Escape Hatch
  programs.nix-ld.enable = true;

  # ---------------------------------------------------------------------------
  system.stateVersion = systemStateVersion; # no touch
}
