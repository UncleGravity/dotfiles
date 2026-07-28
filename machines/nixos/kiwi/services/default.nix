{...}: {
  imports = [
    ./backup
    ./grafana
    # ./guacamole
    ./iperf3.nix
    ./newt.nix
    ./samba.nix
    ./tailscale.nix
    ./uptime-kuma.nix
  ];
}
