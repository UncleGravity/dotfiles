{
  lib,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disko.nix
  ];

  # hcloud VM: without these initrd modules stage-1 can't find the virtio
  # disk and boot hangs before networking comes up.
  boot.initrd.availableKernelModules = ["ata_piix" "ahci" "xhci_pci" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod"];
  services.qemuGuest.enable = true;

  # hcloud CPX servers boot BIOS; the repo default is systemd-boot/EFI.
  boot.loader = {
    systemd-boot.enable = lib.mkForce false;
    efi.canTouchEfiVariables = lib.mkForce false;
    # disko registers /dev/sda as the grub device via the EF02 partition.
    grub.enable = true;
  };

  # Hetzner provides the public IPv4 address through DHCP.
  networking.useDHCP = false;
  systemd.network = {
    enable = true;
    networks."30-wan" = {
      matchConfig.Name = "enp1s0";
      networkConfig.DHCP = "ipv4";
    };
  };
}
