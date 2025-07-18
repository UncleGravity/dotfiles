{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.my.displayManager;
in {
  options.my.displayManager = {
    enable = lib.mkEnableOption "Enable custom display manager configuration";
    desktop = lib.mkOption {
      type = lib.types.enum ["gnome" "plasma"];
      default = "gnome";
      description = "Select the desktop environment to use.";
    };
    rdp = {
      enable = lib.mkEnableOption "Enable RDP (xrdp) server";
      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to open the firewall for RDP.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.xserver.enable = true;
    services.xserver.autorun = true;

    # ---------------------------------------------------------------------------
    # GNOME settings
    services.displayManager.gdm = lib.mkIf (cfg.desktop == "gnome") {
      enable = true;
      autoSuspend = false;
    };
    services.desktopManager.gnome.enable = lib.mkIf (cfg.desktop == "gnome") true;

    # ---------------------------------------------------------------------------
    # Plasma (KDE) settings
    services.xserver.displayManager.sddm.enable = lib.mkIf (cfg.desktop == "plasma") true;
    services.xserver.desktopManager.plasma5.enable = lib.mkIf (cfg.desktop == "plasma") true;

    # ---------------------------------------------------------------------------
    # xrdp configuration
    services.xrdp = lib.mkIf cfg.rdp.enable {
      enable = true;
      defaultWindowManager =
        if cfg.desktop == "gnome"
        then "${pkgs.gnome-session}/bin/gnome-session"
        else if cfg.desktop == "plasma"
        then "startplasma-x11"
        else null;
      openFirewall = cfg.rdp.openFirewall;

      # Configure drive redirection to use a different location (instead of ~/thinclient_drives/)
      # https://manpages.ubuntu.com/manpages/lunar/man5/sesman.ini.5.html
      extraConfDirCommands = ''
        # Remove any existing FuseMountName setting and add our own
        sed -i '/^FuseMountName=/d' $out/sesman.ini
        sed -i '/^\[Chansrv\]/a FuseMountName=/run/user/%u/rdp_drives' $out/sesman.ini
      '';
    };

    # Enable xkb Options in TTY
    console.useXkbConfig = true;
    #console.keyMap = "us-intl";

    # Configure keymap in X11
    services.xserver = {
      xkb.layout = "us";
      xkb.variant = "altgr-intl";
      #xkb.options = "";
      #xkb.model = "macbook79";
    };

    services.xserver.exportConfiguration = true;

    # services.gnome.gnome-remote-desktop.enable = true; # I guess we don't need this?
  };
}
