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
    ./networking.nix
    ./open-webui.nix
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

  security.sudo.wheelNeedsPassword = false;

  # Console login only (SSH is key-only, sudo is passwordless). With
  # mutableUsers = false the config is the sole source of truth: passwd
  # changes on the node will not stick.
  users = {
    mutableUsers = false;
    # nix run nixpkgs#mkpasswd -- -m yescrypt   # type a password, get a hash
    users.${username}.hashedPassword = "$y$j9T$ZaYWzl4QayouVMWxlaINr1$G0yW4zsXL0.8RqV30MFdvB0jDmKA6dKcEPhMvRblDA/";
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
