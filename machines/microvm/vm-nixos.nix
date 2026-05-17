{
  pkgs,
  username,
  ...
}: let
  hostHomeDir = "/Users/${username}";
in {
  imports = [
    ../../modules/common/ssh-keys.nix
  ];

  boot.initrd.systemd.enable = true;

  nix.settings.experimental-features = ["nix-command" "flakes"];

  networking.hostName = "vm-nixos";
  networking.firewall.allowedTCPPorts = [22];
  services.openssh.enable = true;

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
        source = hostHomeDir;
        mountPoint = "/host/home";
      }
    ];

    # Writable overlay on top of the host's read-only /nix/store.
    # Without this, microvm.nix masks nix-daemon (system.nix:48-52),
    # which forces `nix` into single-user mode and breaks for non-root.
    # Absolute path keeps the image in a fixed location regardless of the
    # host cwd from which `vm-nixos` is launched; the parent dir is created
    # by packages/vm-nixos.nix's `mkdir -p "$HOME/.cache/vm-nixos"`.
    writableStoreOverlay = "/nix/.rw-store";
    volumes = [
      {
        image = "${hostHomeDir}/.cache/vm-nixos/store-overlay.img";
        mountPoint = "/nix/.rw-store";
        size = 4096;
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
    nushell
  ];
}
