{...}: let
  # Device Paths
  osDrivePath = "/dev/disk/by-id/nvme-WD_BLACK_SN770M_1TB_245166801032";
  hdd1Path = "/dev/disk/by-id/nvme-WD_Red_SN700_2000GB_25125L800378";
  hdd2Path = "/dev/disk/by-id/nvme-WD_Red_SN700_2000GB_25125L800370";
  hdd3Path = "/dev/disk/by-id/nvme-WD_Red_SN700_2000GB_25125L800343";
  hdd4Path = "/dev/disk/by-id/nvme-WD_Red_SN700_2000GB_25125L800293";
in {
  disko.devices = {
    #############################################################
    #  Disks
    #############################################################
    disk = {
      maindrive = {
        type = "disk";
        device = osDrivePath; # 1TB NVME OS Drive
        content = {
          type = "gpt";
          partitions = {
            # Boot partition
            ESP = {
              size = "512M";
              type = "EF00"; # EFI System Partition
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                # options = [ "umask=0077" ]; # Restrict permissions
              };
            };
            # ZFS partition
            zfs = {
              size = "100%"; # Use the rest of the disk for ZFS
              content = {
                type = "zfs";
                pool = "rpool"; # boot/root pool
              };
            };
          };
        };
      };
      hdd1 = {
        type = "disk";
        device = hdd1Path; # Storage Drive (Bay 01)
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "storagepool";
              };
            };
          };
        };
      };
      hdd2 = {
        type = "disk";
        device = hdd2Path; # Storage Drive (Bay 02)
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "storagepool";
              };
            };
          };
        };
      };
      hdd3 = {
        type = "disk";
        device = hdd3Path; # Storage Drive (Bay 03)
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "storagepool";
              };
            };
          };
        };
      };
      hdd4 = {
        type = "disk";
        device = hdd4Path; # Storage Drive (Bay 04)
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "storagepool";
              };
            };
          };
        };
      };
    };

    #############################################################
    #  Pools
    #############################################################
    zpool = {
      # ---------------------------------------------------------------------------
      #  OS Pool
      rpool = {
        type = "zpool";
        # Workaround: cannot import 'zroot': I/O error in disko tests
        options.cachefile = "none";
        rootFsOptions = {
          compression = "lz4";
          "com.sun:auto-snapshot" = "true";
          atime = "off"; # Disable atime updates for the whole pool by default
          mountpoint = "none";
        };

        # rpool/            # ZFS pool
        # ├── root          # Dataset mounted at /
        # ├── home          # Dataset mounted at /home
        # ├── nix           # Dataset mounted at /nix
        # └── persist       # Dataset mounted at /persist
        datasets = {
          # It's good practice to create a blank dataset for the root of the pool
          # and then create your actual filesystems under it.
          # Disko will automatically create these if they don't exist.
          "root" = {
            type = "zfs_fs";
            mountpoint = "/";
          };
          "home" = {
            type = "zfs_fs";
            mountpoint = "/home";
          };
          "nix" = {
            type = "zfs_fs";
            mountpoint = "/nix";
            options = {
              "com.sun:auto-snapshot" = "false";
            };
          };
          "persist" = {
            type = "zfs_fs";
            mountpoint = "/persist"; # Or any other mountpoint you need
          };
        };

        # Create an initial blank snapshot of the root dataset. Helpful for rollbacks.
        postCreateHook = ''
          zfs snapshot rpool/root@blank
        '';
      };

      # ---------------------------------------------------------------------------
      #  Storage Pool
      storagepool = {
        type = "zpool";

        # Default options
        rootFsOptions = {
          compression = "lz4";
          "com.sun:auto-snapshot" = "true";
          atime = "off"; # Good for performance, less metadata writes.
          xattr = "sa"; # Stores extra metadata on files (used by SAMBA)
          acltype = "posixacl"; # Enable POSIX ACLs
          mountpoint = "none";
        };

        # ─ Topology: two mirror vdevs ──────────────────────────────────────────────
        mode = {
          topology = {
            type = "topology";
            vdev = [
              {
                # first mirror vdev: bay 1 ↔ bay 2
                mode = "mirror";
                members = ["hdd1" "hdd2"];
              }
              {
                # second mirror vdev: bay 3 ↔ bay 4
                mode = "mirror";
                members = ["hdd3" "hdd4"];
              }
            ];
          };
        };

        # Define datasets within the 'storagepool'.
        # storagepool/
        # ├── root            # Dataset mounted at /nas (includes media)
        # └── backups         # Dataset mounted at /nas/backups
        datasets = {
          "root" = {
            type = "zfs_fs";
            options.mountpoint = "/nas"; # Main data share at the root of /nas
            # options.mountpoint = "legacy";
          };
          "backups" = {
            type = "zfs_fs";
            mountpoint = "/nas/backups";
            options = {
              # options.mountpoint = "legacy";
              "com.sun:auto-snapshot" = "false";
            };
          };
        };

        # Create an initial blank snapshot of the /data dataset.
        postCreateHook = ''
          zfs snapshot storagepool/root@blank
        '';
      };
    };
  };
}
