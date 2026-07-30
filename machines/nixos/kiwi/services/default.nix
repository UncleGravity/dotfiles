{...}: {
  imports = [
    ./backup
    ./grafana
    # ./guacamole
    ./iperf3.nix
    ./newt.nix
    ./nfs.nix
    ./samba.nix
    ./tailscale.nix
    ./uptime-kuma.nix
  ];
}
