{
  config,
  pkgs,
  ...
}: {
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

  services.fstrim.enable = true;

  # PSI pressure rises during expected unified-memory reclaim, making
  # systemd-oomd unsuitable for these hosts.
  systemd.oomd.enable = false;

  # LIMIT GPU CLOCK SPEEDS
  # Prevents thermal throttling
  systemd.services.nvidia-gpu-clocks = {
    description = "Set NVIDIA GPU clock ceiling";
    wantedBy = ["multi-user.target"];
    requires = ["nvidia-persistenced.service"];
    after = ["nvidia-persistenced.service"];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${config.hardware.nvidia.package.bin}/bin/nvidia-smi --lock-gpu-clocks=0,2300";
      ExecStop = "${config.hardware.nvidia.package.bin}/bin/nvidia-smi --reset-gpu-clocks";
    };
  };

  environment.systemPackages = with pkgs; [
    nvme-cli
    pciutils
    nvitop
  ];
}
