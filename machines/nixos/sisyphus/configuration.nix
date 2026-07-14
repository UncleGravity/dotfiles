{
  config,
  lib,
  pkgs,
  username,
  ...
}: {
  imports = [
    ./gaming.nix
    ./hardware/disko.nix
    ./hardware/hardware.nix
    ./windows-vm.nix
  ];

  my = {
    profiles = {
      server.enable = true;
      graphical.enable = true;
    };

    displayManager = {
      enable = true;
      desktop = "gnome";
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

  networking.networkmanager.enable = true;

  environment.systemPackages = lib.optional config.my.nvidiaAi.enable (pkgs.llama-cpp.override {cudaSupport = true;});

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
