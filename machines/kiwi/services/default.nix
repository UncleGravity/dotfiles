{...}: {
  imports = [
    ./ai.nix
    ./backup
    ./copyparty.nix
    ./dawarich.nix
    ./grafana
    # ./guacamole
    ./iperf3.nix
    ./nfs.nix
    ./samba.nix
    ./tailscale.nix
    ./tinyauth.nix
    ./uptime-kuma.nix
  ];
}
