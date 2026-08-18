{
  config,
  lib,
  ...
}: {
  #############################################################
  #  Host & User config
  #############################################################
  networking = {
    localHostName = config.networking.hostName;
    computerName = config.networking.hostName;
    wakeOnLan.enable = lib.mkDefault true;
  };
}
