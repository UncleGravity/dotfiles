{
  config,
  username,
  ...
}: {
  imports = [
    ./hardware.nix
    # ./qemu.nix
    # ./vfkit.nix
  ];

  # --- Role profiles ---
  my.profiles = {
    workstation.enable = true;
    graphical.enable = true;
  };

  # ---------------------------------------------------------------------------
  # Enable additional modules for this VM
  my.docker.enable = true;
  my.hackrf.enable = true;

  my.tailscale.enable = true;
  sops.secrets."tailscale/authkey" = {
    mode = "0600";
    owner = "root";
  };
  my.tailscale.authKeyFile = config.sops.secrets."tailscale/authkey".path;

  # ---------------------------------------------------------------------------
  # X11
  my.displayManager = {
    enable = false;
    desktop = "gnome";
  };

  users.users.${username}.password = "angel"; # Set a simple password for SSH access

  # ---------------------------------------------------------------------------
  # Enable CUPS to print documents.
  services.printing.enable = true;
}
