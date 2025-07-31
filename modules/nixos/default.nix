{
  imports = [
    ../common
    ./_core.nix
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
