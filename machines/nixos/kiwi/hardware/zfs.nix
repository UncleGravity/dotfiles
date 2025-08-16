{
  config,
  pkgs,
  ...
}: {
  # ZFS requires a unique hostId for each machine.
  # Generate one with `head -c4 /dev/urandom | od -A n -t x1 | tr -d ' \n'`
  networking.hostId = "80b2c55c";

  # ----------------------------------------------------------
  #  ZFS Boot
  # ----------------------------------------------------------
  boot = {
    # Make sure these filesystems are mountable (Disko's ESP + ZFS pools)
    supportedFilesystems = ["vfat" "zfs"];

    # Tweak kernel params: limit ARC size, disable hibernation
    kernelParams = [
      "zfs.zfs_arc_max=17179869184" # 16 * 1024 * 1024 * 1024 = 16GB
      "nohibernate" # zfs doesn't support hibernation
    ];

    # Enable the ZFS service at boot and tell it where to find disks
    zfs = {
      devNodes = "/dev/disk/by-id/";
      forceImportAll = true;
      requestEncryptionCredentials = true;
    };
  };

  # ----------------------------------------------------------
  #  ZFS Service
  # ----------------------------------------------------------
  services.zfs = {
    autoSnapshot = {
      enable = true; # enable automatic snapshots
      frequent = 4; # How many frequent snapshots to keep
      hourly = 24;
      daily = 7;
      # weekly = 4;
      # monthly = 6;
    };

    autoScrub.enable = true; # periodic background scrub (prevent bit rot)
    trim.enable = true; # TRIM for SSDs (prevent SSD wear)
  };

  # ----------------------------------------------------------
  #  Useful Utilities
  # ----------------------------------------------------------
  environment.systemPackages = [
    pkgs.zfs-prune-snapshots # handy tool to clean up old snapshots
  ];
}
