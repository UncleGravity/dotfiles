{ ... }:

# ------------------------------------------------------------------------------
# IMPORTANT NOTES FOR MANAGING STORAGE WITH DISKO & ZFS:
# ------------------------------------------------------------------------------
#
# This file declaratively defines the disk layout and ZFS configuration for
# this NixOS system using Disko.
#
# --- MANAGING ZFS DATASETS ---
#
# 1. ADDING DATASETS:
#    - To add a new ZFS dataset (e.g., for new storage areas), define it within
#      the `datasets` attribute of the appropriate pool (e.g., `rpool` or
#      `storagepool`).
#    - Specify its `type = "zfs_fs";`, `mountpoint`, and any desired ZFS `options`.
#    - After saving changes, run `nixos-rebuild switch` to apply.
#
# 2. REMOVING DATASETS & RECLAIMING SPACE:
#    This is a two-step process if you want to permanently delete the data and
#    reclaim its disk space:
#
#    Step A: Remove from NixOS/Disko Management
#      - Delete or comment out the dataset's definition from this `disko.nix` file.
#      - Run `nixos-rebuild switch`.
#      - What happens:
#          - NixOS will no longer manage this dataset.
#          - It will likely be unmounted automatically.
#          - THE DATASET AND ITS DATA ARE *NOT* YET DELETED FROM THE ZFS POOL.
#          - The space is *NOT* yet reclaimed.
#
#    Step B: Permanently Destroy Dataset and Reclaim Space (Manual CLI)
#      - Open a terminal.
#      - Identify the full dataset name (e.g., `storagepool/olddata`).
#      - Ensure it's unmounted: `sudo zfs unmount poolname/datasetname`
#        (if it wasn't already).
#      - Destroy the dataset: `sudo zfs destroy poolname/datasetname`
#      - WARNING: `zfs destroy` is IRREVERSIBLE. Double-check the dataset name.
#      - If the dataset has snapshots, `zfs destroy` might fail. You may need to
#        destroy snapshots first (e.g., `zfs destroy poolname/datasetname@snapshotname`)
#        or use `sudo zfs destroy -r poolname/datasetname` to remove the dataset
#        and all its snapshots. Use `-r` with extreme caution.
#      - After successful destruction, the space will be reclaimed by the pool.
#
# 3. ZFS SNAPSHOTS AND SPACE:
#    - Snapshots (manual or automatic, like `com.sun:auto-snapshot`) consume
#      space within the pool.
#    - If you delete a dataset, its snapshots that depend on it might also need
#      to be destroyed to fully reclaim space.
#    - Regularly manage snapshots (e.g., `zfs list -t snapshot`, `zfs destroy pool/fs@snap`)
#      to prevent excessive space usage.
#
# --- MANAGING ZFS POOLS & PHYSICAL DISKS ---
#
# 1. STABLE DEVICE PATHS:
#    - For `devices` in ZFS pool definitions (e.g., `storagepool.devices`),
#      it is CRITICAL to use stable device paths like:
#        - `/dev/disk/by-partlabel/your-label` (preferred if you label partitions)
#        - `/dev/disk/by-id/ata-drivemodel_serial-partX`
#    - Avoid using `/dev/sdX` or `/dev/nvmeXnY` paths directly in pool definitions
#      as they can change between boots, potentially leading to pool import issues.
#    - The partition `name` attribute in `disk.*.content.partitions` (e.g., `name = "zfs-storage-1";`)
#      creates a GPT PARTLABEL, allowing you to use `/dev/disk/by-partlabel/zfs-storage-1`.
#
# 2. REPLACING A FAILED DRIVE (e.g., in a mirror):
#    - This is primarily a ZFS CLI operation.
#    - Identify the failed drive: `sudo zpool status yourpoolname`
#    - Offline the failed drive (if not already offline): `sudo zpool offline yourpoolname /dev/disk/by-id/old-drive-id`
#    - Physically replace the drive.
#    - Add the new drive to the mirror: `sudo zpool replace yourpoolname /dev/disk/by-id/old-drive-id /dev/disk/by-id/new-drive-id`
#      (If the old drive is missing, you might just specify `sudo zpool replace yourpoolname old_drive_guid /dev/disk/by-id/new-drive-id`)
#    - ZFS will start resilvering (rebuilding) the mirror. Monitor with `sudo zpool status yourpoolname`.
#    - If you used specific partition labels that are now on the new disk, ensure this
#      `disko.nix` file still accurately reflects the setup for future rebuilds, especially
#      if the new disk needs partitioning/labeling via Disko first (less common for simple replacements).
#
# --- GENERAL ADVICE ---
#
# 1. REDUNDANCY IS NOT A BACKUP:
#    - ZFS mirrors (like in `storagepool`) protect against single drive failure,
#      not against accidental deletion, file corruption, malware, or disasters.
#    - Implement a separate backup strategy for critical data (e.g., `zfs send/recv`
#      to another machine/pool, or other backup tools).
#
# 2. TEST CHANGES:
#    - Before applying significant storage changes to a production system,
#      test your `disko.nix` configuration in a virtual machine or on a
#      non-critical system if possible.
#
# 3. DISKO ON INITIAL INSTALL VS. REBUILDS:
#    - On initial NixOS installation with Disko, Disko can be destructive
#      (formatting disks, creating partitions).
#    - On subsequent `nixos-rebuild switch` operations on an existing system,
#      Disko is generally non-destructive for existing ZFS pools and datasets
#      unless specific options for erasure are used (which are not in this config).
#      It focuses on creating what's defined but missing.
#
# ------------------------------------------------------------------------------

{
  # 
  disko.devices = {
    #############################################################
    #  Disks
    #############################################################
    disk = {
      maindrive = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-WD_BLACK_SN770M_1TB_245166801032"; # 1TB NVME OS Drive
        content = {
          type = "gpt";
          partitions = [
            # Boot partition
            {
              name = "ESP";
              size = "512M";
              type = "EF00"; # EFI System Partition
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            }
            # ZFS partition
            {
              name = "zfs";
              size = "100%"; # Use the rest of the disk for ZFS
              content = {
                type = "zfs";
                pool = "rpool"; # Name of your ZFS pool
              };
            }
          ];
        };
      };
      hdd1 = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-WD_Red_SN700_2000GB_25125L800378"; # Storage Drive (Bay 01)
        content = {
          type = "gpt";
          partitions = [{
            name = "zfs-bay-1"; # GPT Label for /dev/disk/by-partlabel/zfs-bay-1
            size = "100%";
            type = "FD00"; # Linux RAID partition type
            # No specific 'content' type is strictly needed here if referenced by path in zpool,
            # but you could set type = "FD00"; # Linux RAID if preferred by tools,
            # or leave it for Disko to make a Linux data partition.
          }];
        };
      };
      hdd2 = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-WD_Red_SN700_2000GB_25125L800370"; # Storage Drive (Bay 02)
        content = {
          type = "gpt";
          partitions = [{
            name = "zfs-bay-2"; # GPT Label for /dev/disk/by-partlabel/zfs-bay-2
            size = "100%";
            type = "FD00"; # Linux RAID partition type
          }];
        };
      };
      hdd3 = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-WD_Red_SN700_2000GB_25125L800343"; # Storage Drive (Bay 03)
        content = {
          type = "gpt";
          partitions = [{
            name = "zfs-bay-3"; # GPT Label for /dev/disk/by-partlabel/zfs-bay-3
            size = "100%";
            type = "FD00"; # Linux RAID partition type
          }];
        };
      };
      hdd4 = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-WD_Red_SN700_2000GB_25125L800293"; # Storage Drive (Bay 04)
        content = {
          type = "gpt";
          partitions = [{
            name = "zfs-bay-4"; # GPT Label for /dev/disk/by-partlabel/zfs-bay-4
            size = "100%";
            type = "FD00"; # Linux RAID partition type
          }];
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
          "rpool/root" = {
            type = "zfs_fs";
            mountpoint = "/";
          };
          "rpool/home" = {
            type = "zfs_fs";
            mountpoint = "/home";
          };
          "rpool/nix" = {
            type = "zfs_fs";
            mountpoint = "/nix";
            options = {
              "com.sun:auto-snapshot" = "false";
            };
          };
          "rpool/persist" = {
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
          atime = "off"; # Good for performance, less metadata writes.
          xattr = "sa"; # Stores extra metadata on files (used by SAMBA)
          acltype = "posixacl"; # Enable POSIX ACLs
        };

        # ─ Topology: two mirror vdevs ──────────────────────────────────────────────
        mode = {
          topology = {
            type = "topology";
            vdev = [
              {
                # first mirror vdev: bay 1 ↔ bay 2
                mode    = "mirror";
                members = [
                  "/dev/disk/by-partlabel/zfs-bay-1"
                  "/dev/disk/by-partlabel/zfs-bay-2"
                ];
              }
              {
                # second mirror vdev: bay 3 ↔ bay 4
                mode    = "mirror";
                members = [
                  "/dev/disk/by-partlabel/zfs-bay-3"
                  "/dev/disk/by-partlabel/zfs-bay-4"
                ];
              }
            ];
          };
        };

        # Define datasets within the 'storagepool'.
        # storagepool/
        # ├── root            # Dataset mounted at /nas
        # ├── backups         # Dataset mounted at /nas/backups
        # └── media           # Dataset mounted at /nas/media
        datasets = {
          "storagepool/root" = {
            type = "zfs_fs";
            mountpoint = "/nas"; # Main data share at the root of /nas
          };
          "storagepool/backups" = {
            type = "zfs_fs";
            mountpoint = "/nas/backups";
          };
          "storagepool/media" = {
            type = "zfs_fs";
            mountpoint = "/nas/media";
            options = {
              recordsize = "1M";
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