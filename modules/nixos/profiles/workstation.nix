{
  config,
  lib,
  pkgs,
  ...
}: {
  config = lib.mkIf (config.my.profile == "workstation") {
    networking.networkmanager.enable = lib.mkDefault true;
    my.audio.enable = lib.mkDefault true;

    environment.systemPackages = lib.optionals config.my.desktop.enable (with pkgs; [
      chromium
      ghostty
    ]);
  };
}
