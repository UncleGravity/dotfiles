# hcloud CPX11: 40 GB disk, BIOS boot (GPT + 1M EF02 grub partition).
# The 2G swap partition matters at provision time too: nixos-anywhere's
# --build-on remote evaluates the flake on this 2 GB box.
{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/sda";
    content = {
      type = "gpt";
      partitions = {
        boot = {
          size = "1M";
          type = "EF02";
        };
        swap = {
          size = "2G";
          content = {
            type = "swap";
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
