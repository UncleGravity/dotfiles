{
  lib,
  node,
  pkgs,
  username,
  ...
}: {
  imports = [
    ./disko.nix
    ./huggingface.nix
    ./kernel.nix
    ./networking.nix
    # ./open-webui.nix
    ./users.nix
    ./vllm-laguna.nix
  ];

  my = {
    profile = "server";
    env.home.enable = false;
    ntfy.enable = false;
  };

  hardware.dgx-spark.enable = true;

  services = {
    dgx-dashboard.enable = lib.mkForce node.controller;

    vllm-laguna = {
      # enable = node.controller;
      enable = node.controller;
      autoStart = false;
      listenAddress = node.managementAddress;
      gpuMemoryUtilization = 0.75; # in case of too many OOM errors
    };

    fstrim.enable = true;
  };

  boot = {
    initrd.availableKernelModules = ["nvme"];
    # r8127 is the vendor driver for the RTL8127 management NIC; the dgx-spark
    # module blacklists the mainline r8169 driver for the same chip.
    kernelModules = ["r8127" "mlx5_core"];
  };

  environment.systemPackages = with pkgs; [
    git
    jq
    nvme-cli
    pciutils
    rsync
    tmux
    nvitop
  ];

  systemd.tmpfiles.rules = [
    "d /srv/models 0755 ${username} users -"
  ];

  assertions = [
    {
      assertion = node.id >= 1 && node.id <= 254;
      message = "Spark node IDs must fit in the two /24 fabric networks";
    }
  ];
}
