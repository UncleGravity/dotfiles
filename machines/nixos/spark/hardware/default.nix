{pkgs, ...}: {
  imports = [
    ./disko.nix
  ];

  hardware.dgx-spark.enable = true;

  boot = {
    initrd.availableKernelModules = ["nvme"];

    # r8127 is the vendor driver for the RTL8127 management NIC; the dgx-spark
    # module blacklists the mainline r8169 driver for the same chip.
    kernelModules = ["r8127" "mlx5_core"];
  };

  services = {
    # GB10 CUDA allocations are not fully represented by cgroup memory
    # accounting. Protect the host using available memory instead.
    earlyoom = {
      enable = true;
      # Ask the inference workload to stop below 8%, then force it below 4%.
      freeMemThreshold = 8;
      freeMemKillThreshold = 4;
    };
    fstrim.enable = true;
  };

  # PSI pressure rises during expected unified-memory reclaim, making
  # systemd-oomd unsuitable for these hosts.
  systemd.oomd.enable = false;

  environment.systemPackages = with pkgs; [
    nvme-cli
    pciutils
    nvitop
  ];
}
