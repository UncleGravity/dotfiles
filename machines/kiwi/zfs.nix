{ config, pkgs, ... }:

{
  # ZFS requires a unique hostId for each machine.
  # Generate one with `head -c4 /dev/urandom | od -A n -t x1 | tr -d ' \n'`
  networking.hostId = "80b2c55c";

  # ——————————————————————————————————————————————————————————
  #  ZFS Boot
  # ——————————————————————————————————————————————————————————
   # Make sure these filesystems are mountable (Disko’s ESP + your ZFS pools)
  boot.supportedFilesystems = [ "vfat" "zfs" ];

  # Tweak kernel params: limit ARC size, disable hibernation
  boot.kernelParams = [
    "zfs.zfs_arc_max=17179869184" # 16 * 1024 * 1024 * 1024 = 16GB
    "nohibernate" # zfs doesn't support hibernation
  ];

  # Enable the ZFS service at boot and tell it where to find your disks
  boot.zfs = {
    devNodes                   = "/dev/disk/by-id/";
    forceImportAll             = true;
    requestEncryptionCredentials = true;
  };

  # ——————————————————————————————————————————————————————————
  #  ZFS Services
  # ——————————————————————————————————————————————————————————
  services.zfs = {
    autoSnapshot.enable = true; # enable automatic snapshots
    autoSnapshot.frequent = 4; # How many frequent snapshots to keep
    autoSnapshot.hourly = 24;
    autoSnapshot.daily = 7;
    # autoSnapshot.weekly = 4;
    # autoSnapshot.monthly = 6;

    autoScrub.enable = true;  # periodic background scrub (prevent bit rot)
    trim.enable      = true;  # TRIM for SSDs (prevent SSD wear)
  };

  # ——————————————————————————————————————————————————————————
  #  Useful Utilities
  # ——————————————————————————————————————————————————————————
  environment.systemPackages = [
    pkgs.zfs-prune-snapshots   # handy tool to clean up old snapshots
  ];
}