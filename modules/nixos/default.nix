{
  imports = [
    ../common
    ./_core.nix
    # Role profiles
    ./server.nix
    ./graphical.nix
    ./workstation.nix
    # Feature modules
    ./display-manager.nix
    ./docker.nix
    ./escape-hatch.nix
    # ./grafana/grafana.nix
    ./guacamole
    ./hackrf.nix
    ./immich.nix
    ./gui.nix
    ./nh.nix
    ./tailscale.nix
  ];
}
