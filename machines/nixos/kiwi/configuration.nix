{
  config,
  inputs,
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
    ./services/guacamole
    # ./services/wifi.nix
    "${inputs.self}/modules/nixos/_core.nix"
  ];

  # --- Role profiles ---
  # kiwi is a NAS (server) with GNOME for Guacamole/RDP (graphical).
  my.profiles = {
    server.enable = true;
    graphical.enable = true;
  };

  # ---------------------------------------------------------------------------
  # Enable server-specific modules
  my.displayManager = {
    enable = true;
    desktop = "gnome";
    rdp.enable = true; # For Guacamole
  };

  # Enable server services (beyond the defaults from _core.nix)
  # my.guacamole: enabled + secret wired in ./services/guacamole/default.nix
  # my.grafana.enable = true;      # TODO: Modularize grafana.nix
  # Note: services/samba.nix is imported directly above (machine-specific)

  # Tailscale auth key (my.tailscale.enable comes from _core.nix).
  sops.secrets."tailscale/authkey" = {
    mode = "0600";
    owner = "root";
  };
  my.tailscale.authKeyFile = config.sops.secrets."tailscale/authkey".path;

  services.iperf3 = {
    enable = true;
    openFirewall = true; # tcp/udp = [ 5201 ]
  };

  # kiwi is a server profile but uses WiFi, so enable NM explicitly here.
  # (workstation profile enables NM by default.)
  networking.networkmanager.enable = true;
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
}
