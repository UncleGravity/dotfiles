{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.my.desktop;
in {
  options.my.desktop = {
    enable = lib.mkEnableOption "desktop environment";

    environment = lib.mkOption {
      type = lib.types.enum ["gnome" "plasma"];
      default = "gnome";
      description = "Desktop environment to use";
    };

    rdp = {
      enable = lib.mkEnableOption "xrdp remote desktop access";

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to open the firewall for RDP";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    hardware.graphics.enable = true;

    services = {
      xserver = {
        enable = true;
        autorun = true;
        exportConfiguration = true;
        xkb = {
          layout = "us";
          variant = "altgr-intl";
        };
      };

      displayManager = {
        gdm = lib.mkIf (cfg.environment == "gnome") {
          enable = true;
          autoSuspend = false;
        };
        sddm.enable = lib.mkIf (cfg.environment == "plasma") true;
      };

      desktopManager = {
        gnome.enable = lib.mkIf (cfg.environment == "gnome") true;
        plasma6.enable = lib.mkIf (cfg.environment == "plasma") true;
      };

      xrdp = lib.mkIf cfg.rdp.enable {
        enable = true;
        defaultWindowManager =
          if cfg.environment == "gnome"
          then "${pkgs.gnome-session}/bin/gnome-session"
          else "startplasma-x11";
        openFirewall = cfg.rdp.openFirewall;

        extraConfDirCommands = ''
          sed -i '/^FuseMountName=/d' $out/sesman.ini
          sed -i '/^\[Chansrv\]/a FuseMountName=/run/user/%u/rdp_drives' $out/sesman.ini
        '';
      };
    };

    console.useXkbConfig = true;
  };
}
