{
  config,
  lib,
  ...
}: {
  # VFKIT ONLY
  # Set proper terminal type for color support
  environment.variables = {
    TERM = "xterm-256color";
    COLORTERM = "truecolor";
  };

  # # Configure getty to use proper terminal type via environment
  # systemd.services."getty@hvc0".environment.TERM = "xterm-256color";
  # systemd.services."serial-getty@hvc0".environment.TERM = "xterm-256color";

  # ---------------------------------------------------------------------------
  # Rosetta
  # ---------------------------------------------------------------------------

  # Enable Rosetta for x86_64 binary translation on aarch64 host
  virtualisation.rosetta.enable = true;
  virtualisation.rosetta.mountTag = "rosetta";

  # ---------------------------------------------------------------------------
  # Kernel
  # ---------------------------------------------------------------------------
  # Prefer latest kernel for better virtiofs support
  # boot.kernelPackages = pkgs.linuxPackages_latest;

  # Make sure initrd has the right virtio modules
  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtiofs"
    "virtio"
    "virtio_ring"
    "virtio_blk"
    "virtio_net"
  ];

  # ---------------------------------------------------------------------------
  # Filesystems
  # ---------------------------------------------------------------------------
  # ROOT - nixos.raw with label=nixos is created by our module
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  # Mount host's /nix/store as read-only lower layer
  fileSystems."/nix/.ro-store" = {
    device = "nix-store";
    fsType = "virtiofs";
    neededForBoot = true;
    options = ["ro"];
  };

  # Create tmpfs for writable overlay upper/work dirs
  fileSystems."/nix/.rw-store" = {
    fsType = "tmpfs";
    neededForBoot = true;
    options = ["mode=0755"];
  };

  # Overlay filesystem for /nix/store (writable on top of read-only host store)
  fileSystems."/nix/store" = {
    overlay = {
      lowerdir = ["/nix/.ro-store"];
      upperdir = "/nix/.rw-store/upper";
      workdir = "/nix/.rw-store/work";
    };
  };

  # Load closure registration into VM's Nix database
  # So that our nix hack works just like qemu-vm.nix
  boot.postBootCommands = lib.mkIf config.nix.enable ''
    if [[ "$(cat /proc/cmdline)" =~ regInfo=([^ ]*) ]]; then
      ${config.nix.package.out}/bin/nix-store --load-db < ''${BASH_REMATCH[1]}
    fi
  '';
  # ---------------------------------------------------------------------------
  # Home
  fileSystems."/host/home" = {
    device = "home"; # matches mountTag
    fsType = "virtiofs";
    # neededForBoot = true;
  };

  # ---------------------------------------------------------------------------
  # So SOPS can find ssh keys
  fileSystems."/vm/ssh" = {
    device = "vm-ssh"; # matches mountTag
    fsType = "virtiofs";
    options = ["ro"]; # keep it read‑only inside the VM
    neededForBoot = true;
  };
  # ---------------------------------------------------------------------------
}
