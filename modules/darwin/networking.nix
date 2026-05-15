{
  lib,
  hostname,
  ...
}: {
  #############################################################
  #  Host & User config
  #############################################################
  networking = {
    hostName = hostname;
    localHostName = hostname;
    computerName = hostname;
    # system.defaults.smb.NetBIOSName = lib.mkDefault hostname; # Often derived from hostname
    wakeOnLan.enable = lib.mkDefault true;
  };
}
