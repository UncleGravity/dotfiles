{
  config,
  lib,
  ...
}: {
  options.my.audio.enable = lib.mkEnableOption "PipeWire audio support";

  config = lib.mkIf config.my.audio.enable {
    security.rtkit.enable = true;
    services.pulseaudio.enable = false;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
    };
  };
}
