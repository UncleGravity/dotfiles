{
  self,
  inputs,
  systemStateVersion,
  config,
  ...
}: let
  MODULES_DIR = "${self}/modules";
in {
  imports = [
    # Disko auto-generates fileSystems entries (originally managed in hardware.nix)
    inputs.disko.nixosModules.disko
    ./disko.nix
    ./hardware.nix
    # ./wifi.nix
    "${self}/modules/nixos/_core.nix"
    ./zfs.nix
    "${MODULES_DIR}/sops.nix"
    "${MODULES_DIR}/nixos/tailscale.nix"
    "${MODULES_DIR}/nixos/docker.nix"
    "${MODULES_DIR}/nixos/samba.nix"
    "${MODULES_DIR}/nixos/guacamole/"
    "${MODULES_DIR}/nixos/grafana/grafana.nix"
    "${MODULES_DIR}/nixos/display-manager.nix"
    # "${MODULES_DIR}/nixos/immich.nix"
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

  networking.firewall.allowedTCPPorts = [ 19999 ]; # netdata #TODO: Remove this

  # ---------------------------------------------------------------------------
  # Escape Hatch
  programs.nix-ld.enable = true;

  # ---------------------------------------------------------------------------
  system.stateVersion = systemStateVersion; # no touch
}
