{
  config,
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
  ];

  # ---------------------------------------------------------------------------
  # Secrets
  sops.secrets."tailscale/authkey" = {
    mode = "0600";
    owner = "root";
  };

  # ---------------------------------------------------------------------------
  # Custom modules
  my = {
    # --- Active profiles ---
    profiles = {
      server.enable = true;
      graphical.enable = true;
    };

    # ---------------------------------------------------------------------------
    # Enable server-specific modules
    displayManager = {
      enable = true;
      desktop = "gnome";
      rdp.enable = true; # For Guacamole
    };

    docker.enable = true;
    tailscale.enable = true;
    tailscale.authKeyFile = config.sops.secrets."tailscale/authkey".path;
  };

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
