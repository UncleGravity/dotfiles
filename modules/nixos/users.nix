{
  config,
  username,
  hostname,
  pkgs,
  ...
}: let
  home = config.users.users.${username}.home;
in {
  # ---------------------------------------------------------------------------
  # Define a user account. Don't forget to set a password with 'passwd'.
  # TTY autologin is configured explicitly by hosts that need it.
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

  # sops-nix creates parents for home-directory secret paths as root.
  systemd.tmpfiles.rules = [
    "d ${home}/.config 0700 ${username} users -"
    "d ${home}/.config/zsh 0700 ${username} users -"
    "d ${home}/.config/zsh/secrets 0700 ${username} users -"
  ];

  # Networking
  networking = {
    hostName = hostname;
  };
}
