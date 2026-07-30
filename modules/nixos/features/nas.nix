{
  config,
  lib,
  ...
}: let
  cfg = config.my.nas;
  unasExportRoot = "192.168.1.174:/volume/02ce26f0-d325-4f9d-a23a-ac8fbe4c467d/.srv/.unifi-drive";
  automountOptions = [
    "proto=tcp"
    "_netdev"
    "nofail"
    "x-systemd.automount"
    "x-systemd.idle-timeout=10min"
    "x-systemd.mount-timeout=15s"
  ];
in {
  options.my.nas = {
    unas = {
      ai.enable = lib.mkEnableOption "the UNAS ai shared drive";
      personal.enable = lib.mkEnableOption "the UNAS personal shared drive";
    };
    kiwi.enable = lib.mkEnableOption "Kiwi's NAS export";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.unas.ai.enable {
      fileSystems."/mnt/nas/unas/ai" = {
        # This firmware exports the backing path; /var/nfs/shared/ai is unavailable.
        device = "${unasExportRoot}/ai/.data";
        fsType = "nfs";
        options = ["nfsvers=3"] ++ automountOptions;
      };
    })

    (lib.mkIf cfg.unas.personal.enable {
      fileSystems."/mnt/nas/unas/personal" = {
        device = "${unasExportRoot}/personal/.data";
        fsType = "nfs";
        options = ["nfsvers=3"] ++ automountOptions;
      };
    })

    (lib.mkIf cfg.kiwi.enable {
      fileSystems."/mnt/nas/kiwi" = {
        device = "192.168.1.200:/";
        fsType = "nfs";
        options = ["nfsvers=4.2"] ++ automountOptions;
      };
    })
  ];
}
