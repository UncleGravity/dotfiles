{...}: {
  imports = [
    ./hardware
    ./networking
    ./services
    ./users.nix
  ];

  # ---------------------------------------------------------------------------
  # Custom modules
  my = {
    profile = "server";
    audio.enable = true;

    # Enable server-specific modules
    desktop = {
      enable = true;
      environment = "gnome";
      rdp.enable = true; # For Guacamole
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
