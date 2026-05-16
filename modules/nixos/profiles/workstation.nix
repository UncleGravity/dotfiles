{
  config,
  lib,
  username,
  pkgs,
  ...
}: {
  config = lib.mkIf config.my.profiles.workstation.enable {
    # ---------------------------------------------------------------------------
    # NetworkManager — interactive hosts. Servers that happen to need it
    networking.networkmanager.enable = true;

    # ---------------------------------------------------------------------------
    # Autologin (TTY) — convenient on workstations / dev VMs; never on servers.
    services.getty.autologinUser = "${username}";

    environment.systemPackages = with pkgs; [
      chromium # Web browser
      ghostty # arigatogosaimasu hashimoto san
    ];
  };
}
