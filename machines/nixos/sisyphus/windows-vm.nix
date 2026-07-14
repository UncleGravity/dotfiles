{
  lib,
  pkgs,
  username,
  ...
}: {
  specialisation.windows-vm.configuration = {
    system.nixos.tags = ["windows-vm"];

    # Keep the Linux desktop on the Ryzen iGPU and reserve both RTX 4090
    # functions for the Windows guest from the beginning of stage 1.
    my.nvidiaAi.enable = lib.mkForce false;
    services.xserver.videoDrivers = lib.mkForce ["amdgpu"];

    hardware = {
      amdgpu.initrd.enable = true;
      graphics.enable = true;
    };

    boot = {
      blacklistedKernelModules = ["nouveau"];
      initrd.kernelModules = [
        "vfio"
        "vfio_pci"
        "vfio_iommu_type1"
      ];
      kernelParams = [
        "iommu=pt"
        "vfio-pci.ids=10de:2684,10de:22ba"
      ];
    };

    virtualisation.libvirtd = {
      enable = true;
      onBoot = "ignore";
      onShutdown = "shutdown";
      qemu.swtpm.enable = true;
    };

    programs.virt-manager.enable = true;

    users.users.${username}.extraGroups = ["libvirtd"];

    environment.systemPackages = [pkgs.pciutils];

    systemd.tmpfiles.rules = [
      "d /data/iso 0775 ${username} users - -"
      "d /data/vm 0775 ${username} users - -"
    ];
  };
}
