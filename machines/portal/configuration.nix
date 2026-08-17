{
  inputs,
  username,
  ...
}: {
  imports = [
    ../../modules/nixos
    inputs.self.nixosModules.inference
    ./hardware
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
  system.stateVersion = "26.05";

  # Home
  home-manager.users.${username}.imports = [./home.nix];

  my = {
    profile = "server";
    ntfy.enable = true;
    env.home.enable = false; # Cloud VPS = no env secrets
  };

  # Swap
  zramSwap.enable = true;

  # Periodically erase and consolidate SSD flash pages during idle time
  services.fstrim.enable = true;
}
