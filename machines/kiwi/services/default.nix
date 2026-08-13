{...}: {
  imports = [
    ./ai.nix
    ./backup
    ./copyparty.nix
    ./dawarich.nix
    ./grafana
    # ./guacamole
    ./iperf3.nix
    ./samba.nix
    ./tailscale.nix
    ./tinyauth.nix
    ./uptime-kuma.nix
  ];
}
