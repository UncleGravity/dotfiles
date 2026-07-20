{
  config,
  username,
  ...
}: {
  imports = [
    ./gaming.nix
    ./hardware/disko.nix
    ./hardware/hardware.nix
    ./inference
    ./windows-vm.nix
  ];

  my = {
    profile = "workstation";
    power.alwaysOn = true;

    desktop = {
      enable = true;
      environment = "gnome";
    };

    docker.enable = true;
    escape-hatch.enable = true;
    nvidiaAi.enable = true;
    tailscale = {
      enable = true;
      authKeyFile = config.sops.secrets."tailscale/authkey".path;
      advertiseRoutes = [];
      enableExitNode = false;
    };
  };

  sops.secrets."tailscale/authkey" = {
    mode = "0600";
    owner = "root";
  };

  services.fstrim.enable = true;

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 25;
  };

  systemd.tmpfiles.rules = [
    "d /data 0775 ${username} users - -"
  ];

  users.users.${username}.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEInOZ8KpWVwbYHVSkTjAeFxtRxNi3lnTkJ4n56g6Acr angel@banana"
  ];
}
