{
  config,
  lib,
  ...
}: {
  config = lib.mkIf (config.my.profile == "server") {
    my.power.alwaysOn = lib.mkDefault true;
  };
}
