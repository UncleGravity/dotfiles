{
  username,
  hostname,
  pkgs,
  ...
}: {
  # ---------------------------------------------------------------------------
  # Define a user account. Don't forget to set a password with 'passwd'.
  # TTY autologin is gated by workstation profile (modules/nixos/workstation.nix).
  users = {
    users.${username} = {
      isNormalUser = true;
      description = "me";
      extraGroups = [
        "networkmanager"
        "wheel" # sudo
      ];
    };
    defaultUserShell = pkgs.zsh;
  };
  # Networking
  networking = {
    hostName = hostname;
  };
}
