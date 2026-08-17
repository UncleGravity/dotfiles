{
  inputs,
  username,
  ...
}: {
  imports = [
    ../../modules/nixos
    inputs.self.nixosModules.inference
    ./hardware
    ./inference
    ./services
    ./specialisations
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
  system.stateVersion = "26.05";

  # Home
  home-manager.users.${username}.imports = [./home.nix];

  my = {
    profile = "workstation";
    unas = {
      ai.enable = true;
      personal.enable = true;
    };
    power.alwaysOn = true;

    desktop = {
      enable = true;
      environment = "gnome";
    };

    docker.enable = true;
    escape-hatch.enable = true;
    nvidiaAi.enable = true;
  };

  # Periodically erase and consolidate SSD flash pages during idle time
  services.fstrim.enable = true;

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 25;
  };

  systemd.tmpfiles.rules = [
    "d /data 0775 ${username} users - -"
  ];
}
