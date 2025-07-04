## TODO: CONVERT TO MODULE.
{ lib, config, pkgs, ... }:
let
  uid  = 1000;   # your user
  gid  = 100;    # “users” group
in
{
  fileSystems."/mnt/t7" = {
    device          = "/dev/disk/by-uuid/26FA-BD83";
    fsType          = "exfat";

    # --- systemd options ---
    options = [
      "nofail"                        # don’t break boot if absent
      "x-systemd.automount"           # creates /mnt/t7.automount
      "x-systemd.device-timeout=5"    # fail fast when not present
      "x-systemd.idle-timeout=10m"    # unmount 10 min after last use
      # --- normal mount flags ---
      "uid=${builtins.toString uid}"
      "gid=${builtins.toString gid}"
      "umask=0022"
    ];

    neededForBoot = false;            # USB isn’t required for / to mount
  };

  ## 2 · Create the directory with correct permissions at every switch
  systemd.tmpfiles.rules = [
    "d /mnt/t7 0775 ${builtins.toString uid} ${builtins.toString gid} -"
  ];
}
