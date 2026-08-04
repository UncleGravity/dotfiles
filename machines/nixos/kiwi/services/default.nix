{...}: {
  imports = [
    ./ai.nix
    ./backup
    ./copyparty.nix
    ./grafana
    # ./guacamole
    ./iperf3.nix
    ./newt.nix
    ./nfs.nix
    ./samba.nix
    ./tailscale.nix
    ./tinyauth.nix
    ./uptime-kuma.nix
  ];
}
