{
  inputs,
  systemStateVersion,
  ...
}: {
  imports = [
    ./hardware/disko.nix # Disko auto-generates fileSystems entries (originally managed in hardware.nix)
    ./hardware/hardware.nix
    ./hardware/mounts.nix
    ./hardware/zfs.nix
    ./services/backup
    ./services/samba.nix
    ./services/grafana/grafana.nix
    # ./services/wifi.nix
    "${inputs.self}/modules/nixos/_core.nix"
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
  # Note: services/samba.nix is imported directly above (machine-specific)

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

  # ---------------------------------------------------------------------------
  # Escape Hatch
  programs.nix-ld.enable = true;

  # ---------------------------------------------------------------------------
  system.stateVersion = systemStateVersion; # no touch
}
