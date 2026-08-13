_: let
  systemDisk = "/dev/disk/by-id/nvme-Samsung_SSD_980_PRO_2TB_S6B0NU0W713912D";
  btrfsOptions = ["compress=zstd:3" "noatime"];
in {
  disko.devices.disk.system = {
    type = "disk";
    device = systemDisk;
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          priority = 1;
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = ["umask=0077"];
          };
        };

        root = {
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = ["-f"];
            subvolumes = {
              "/root" = {
                mountpoint = "/";
                mountOptions = btrfsOptions;
              };
              "/home" = {
                mountpoint = "/home";
                mountOptions = btrfsOptions;
              };
              "/nix" = {
                mountpoint = "/nix";
                mountOptions = btrfsOptions;
              };
              "/log" = {
                mountpoint = "/var/log";
                mountOptions = btrfsOptions;
              };
              "/data" = {
                mountpoint = "/data";
                mountOptions = btrfsOptions;
              };
            };
          };
        };
      };
    };
  };
}
