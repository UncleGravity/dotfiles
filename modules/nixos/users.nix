{
  config,
  lib,
  username,
  hostname,
  pkgs,
  ...
}: {
  # ---------------------------------------------------------------------------
  # Define a user account. Don't forget to set a password.
  # TTY autologin is configured explicitly by hosts that need it.
  users = {
    mutableUsers = lib.mkDefault false;

    users.${username} = {
      uid = lib.mkDefault 1000;
      group = lib.mkDefault "users";
      isNormalUser = true;
      description = "me";
      extraGroups = [
        "networkmanager"
        "wheel" # sudo
      ];
    };
    # defaultUserShell = pkgs.zsh;
    defaultUserShell = pkgs.nushell;
  };

  # SSH is key-only. No password.
  security.sudo.wheelNeedsPassword = lib.mkDefault false;

  # Complain if I forgor to set a password.
  assertions = [
    {
      assertion =
        config.users.mutableUsers
        || config.users.users.${username}.hashedPasswordFile != null;
      message = ''
        users.mutableUsers is false, but users.users.${username}.hashedPasswordFile is not set.
        Declare a password hash file for ${username}, or set users.mutableUsers = true.
      '';
    }
  ];

  # Networking
  networking = {
    hostName = hostname;
  };
}
