{
  inputs,
  username,
  ...
}: {
  imports = [
    ../../modules/nixos
    inputs.self.nixosModules.inference
    inputs.copyparty.nixosModules.default
    ./hardware
    ./networking
    ./services
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
  system.stateVersion = "24.11";

  # Home
  home-manager.users.${username}.imports = [./home.nix];

  # ---------------------------------------------------------------------------
  # Custom modules
  my = {
    profile = "server";
    audio.enable = true;
    unas = {
      ai.enable = true;
      personal.enable = true;
    };

    # Enable server-specific modules
    desktop = {
      enable = true;
      environment = "gnome";
    };

    docker.enable = true;
  };

  # services.udisks2.enable = true; # Auto-mount external drives
  # services.udiskie.enable = true;
  # services.devmon.enable = true;

  # ---------------------------------------------------------------------------
  # Escape Hatch
  programs.nix-ld.enable = true;
}
