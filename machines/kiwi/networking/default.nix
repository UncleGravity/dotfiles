_: {
  networking = {
    networkmanager.enable = true;
    firewall.allowedTCPPorts = [19999]; # netdata #TODO: Remove this
  };
}
