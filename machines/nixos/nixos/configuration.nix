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

  my.profile = "workstation";

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

  users.users.${username}.password = "angel"; # Set a simple password for SSH access
  services.getty.autologinUser = username;

  # ---------------------------------------------------------------------------
  # Enable CUPS to print documents.
  services.printing.enable = true;
}
