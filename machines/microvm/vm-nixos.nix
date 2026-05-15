{
  pkgs,
  ...
}: {
  networking.hostName = "vm-nixos";

  boot.initrd.systemd.enable = true;

  microvm = {
    hypervisor = "vfkit";
    vcpu = 2;
    mem = 1024;
    socket = "/tmp/vm-nixos.sock";

    # Enable Internet Access
    interfaces = [
      {
        type = "user";
        id = "net0";
        mac = "02:00:00:00:00:01";
      }
    ];
    # ---------------------------------------

    # Disk Config
    shares = [
      {
        proto = "virtiofs";
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
      }
      {
        proto = "virtiofs";
        tag = "host-home";
        source = "/Users/angel";
        mountPoint = "/host/home";
      }
    ];
  };
  # ---------------------------------------

  # User Config
  services.getty.autologinUser = "angel";

  users.users.angel = {
    isNormalUser = true;
    initialPassword = "angel";
    extraGroups = ["wheel"];
    shell = pkgs.bashInteractive;
  };

  security.sudo.wheelNeedsPassword = false;
  # ---------------------------------------

  programs.bash.loginShellInit = ''
    if [ "$(id -un)" = "angel" ]; then
      vm_nixos_pwd_file="/host/home/.cache/vm-nixos/pwd"
      if [ -r "$vm_nixos_pwd_file" ]; then
        vm_nixos_pwd="$(head -n 1 "$vm_nixos_pwd_file")"
        if [ -d "$vm_nixos_pwd" ]; then
          cd "$vm_nixos_pwd"
        else
          cd /host/home
        fi
        unset vm_nixos_pwd
      elif [ -d /host/home ]; then
        cd /host/home
      fi
      unset vm_nixos_pwd_file
    fi
  '';

  environment.systemPackages = with pkgs; [
    # clang
    # gcc
    yazi
    cowsay
    xilinx-bootgen
    cyme
  ];
}
