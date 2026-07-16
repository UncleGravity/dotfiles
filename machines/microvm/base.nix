{
  pkgs,
  username,
  hostname,
  ...
}: let
  hostHomeDir = "/Users/${username}";

  # Derive a stable locally-administered MAC (02: prefix) from the VM name so
  # multiple VMs on the same vmnet subnet don't collide.
  macFromName = name: let
    h = builtins.hashString "md5" name;
    seg = i: builtins.substring (i * 2) 2 h;
  in "02:${seg 0}:${seg 1}:${seg 2}:${seg 3}:${seg 4}";

  mac = macFromName hostname;
in {
  imports = [
    ../../modules/common/caches.nix
    ../../modules/common/ssh-keys.nix
  ];

  boot.initrd.systemd.enable = true;

  nix.settings.experimental-features = ["nix-command" "flakes"];

  networking.hostName = hostname;
  networking.firewall.allowedTCPPorts = [22];
  services.openssh.enable = true;

  microvm = {
    hypervisor = "vfkit";
    socket = "/tmp/vm-${hostname}.sock";

    # Enable Internet Access
    interfaces = [
      {
        type = "user";
        id = "net0";
        inherit mac;
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
    # host cwd from which `vm` is launched; the parent dir is created by
    # packages/vm.nix's `mkdir -p "$HOME/.cache/vm/<name>"`.
    writableStoreOverlay = "/nix/.rw-store";
    volumes = [
      {
        image = "${hostHomeDir}/.cache/vm/${hostname}/store-overlay.img";
        mountPoint = "/nix/.rw-store";
        size = 4096;
      }
    ];
  };
  # ---------------------------------------

  # User Config
  services.getty.autologinUser = username;

  users.users.${username} = {
    isNormalUser = true;
    initialPassword = username;
    extraGroups = ["wheel"];
    shell = pkgs.bashInteractive;
  };

  security.sudo.wheelNeedsPassword = false;
  # ---------------------------------------

  # Sync host cwd → guest path so the login shell lands in the matching
  # directory under /host/home (cwd file written by packages/vm.nix).
  programs.bash.loginShellInit = ''
    if [ "$(id -un)" = "${username}" ]; then
      vm_pwd_file="/host/home/.cache/vm/${hostname}/pwd"
      if [ -r "$vm_pwd_file" ]; then
        vm_pwd="$(head -n 1 "$vm_pwd_file")"
        if [ -d "$vm_pwd" ]; then
          cd "$vm_pwd"
        else
          cd /host/home
        fi
        unset vm_pwd
      elif [ -d /host/home ]; then
        cd /host/home
      fi
      unset vm_pwd_file
    fi
  '';
}
