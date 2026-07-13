{
  config,
  lib,
  pkgs,
  username,
  ...
}: let
  cfg = config.my.nvidiaAi;
in {
  options.my.nvidiaAi.enable = lib.mkEnableOption "NVIDIA AI development and inference support";

  config = lib.mkIf cfg.enable {
    services.xserver.videoDrivers = ["amdgpu" "nvidia"];

    hardware = {
      graphics = {
        enable = true;
        enable32Bit = true;
      };

      nvidia = {
        open = true;
        branch = "production";
        modesetting.enable = true;
        nvidiaPersistenced = true;
      };

      nvidia-container-toolkit.enable = true;
    };

    users.users.${username}.extraGroups = ["render" "video"];

    environment.systemPackages = with pkgs; [
      nvtopPackages.nvidia
      vulkan-tools
    ];
  };
}
