{...}: {
  imports = [
    ./hardware
  ];

  my = {
    profile = "server";
    ntfy.enable = true;
    env.home.enable = false; # Cloud VPS = no env secrets
  };

  # Swap
  zramSwap.enable = true;

  # Periodically erase and consolidate SSD flash pages during idle time
  services.fstrim.enable = true;
}
