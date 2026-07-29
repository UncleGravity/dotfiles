{pkgs, ...}: {
  imports = [
    ./disko.nix
    ./kernel.nix
  ];

  hardware.dgx-spark.enable = true;

  boot = {
    initrd.availableKernelModules = ["nvme"];

    # r8127 is the vendor driver for the RTL8127 management NIC; the dgx-spark
    # module blacklists the mainline r8169 driver for the same chip.
    kernelModules = ["r8127" "mlx5_core"];
  };

  services.fstrim.enable = true;

  environment.systemPackages = with pkgs; [
    nvme-cli
    pciutils
    nvitop
  ];
}
