{...}: {
  services.iperf3 = {
    enable = true;
    openFirewall = true; # tcp/udp = [ 5201 ]
  };
}
