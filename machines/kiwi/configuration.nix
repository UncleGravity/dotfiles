{
  self,
  inputs,
  systemStateVersion,
  ...
}: let
  MODULES_DIR = "${self}/modules";
in {
  imports = [
    # Disko auto-generates fileSystems entries (originally managed in hardware.nix)
    inputs.disko.nixosModules.disko
    ./disko.nix
    ./hardware.nix
    ./mounts.nix
    ./zfs.nix
    ./backup
    # ./wifi.nix
    "${self}/modules/nixos/_core.nix"
    "${MODULES_DIR}/sops.nix"
    "${MODULES_DIR}/nixos/tailscale.nix"
    "${MODULES_DIR}/nixos/docker.nix"
    "${MODULES_DIR}/nixos/samba.nix"
    "${MODULES_DIR}/nixos/guacamole/"
    "${MODULES_DIR}/nixos/grafana/grafana.nix"
    "${MODULES_DIR}/nixos/display-manager.nix"
  ];

  # ---------------------------------------------------------------------------
  # X11 / GNOME
  my.displayManager = {
    enable = true;
    desktop = "gnome";
    rdp.enable = true; # For Guacamole
  };

  services.iperf3 = {
    enable = true;
    openFirewall = true; # tcp/udp = [ 5201 ]
  };

  networking.networkmanager.settings = {
    "connection"."wifi.powersave" = 2;   # 2 = disabled
  };

  networking.firewall.allowedTCPPorts = [ 19999 ]; # netdata #TODO: Remove this

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
