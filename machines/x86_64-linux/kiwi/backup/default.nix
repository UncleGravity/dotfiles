{
  pkgs,
  config,
  hostname,
  ...
}:
# Inspo: https://www.arthurkoziel.com/restic-backups-b2-nixos/
# Cache Dir: /var/cache/restic-backups-${name}
let
  backupDataset = "storagepool/root";
  mountPoint = "/nas"; # List zfs datasets and mountpoints: `zfs list`
  snapshotName = "backup"; # List zfs snapshots: zfs list -t snapshot

  # Notification helper
  notify = message: "NTFY_TOPIC=$(cat ${config.sops.secrets."ntfy/topic".path}) ${pkgs.ntfy-sh}/bin/ntfy pub -m \"${message}\" -t \"${hostname} Backup\"";
in {
  # -----------------------------------------------------------------------------------------------
  # Secrets
  sops.secrets."backup/b2.env" = {}; # For Backblaze B2
  sops.secrets."backup/b2/restic/repo" = {}; # For Backblaze B2
  sops.secrets."backup/b2/restic/password" = {}; # For Backblaze B2
  sops.secrets."backup/t7-password" = {}; # For Backblaze B2
  sops.secrets."ntfy/topic" = {}; # For NTFY notifications

  # --- B2 ----------------------------------------------------------
  systemd.services."restic-backups-b2" = {
    unitConfig = {
      RequiresMountsFor = ["${mountPoint}"]; # Fail if /nas is not mounted
      After = ["network-online.target"]; # Internet required
      Wants = ["network-online.target"]; # Internet Required
      OnFailure = ["notify-backup-failed@%n.service"]; # "%n" becomes "restic-backups-[b2|t7]"
    };
    # Allows us to use ./<snapshot> as restic path
    # See (<mountpoint>/<files>) instead of <mountpoint>/nas/.zfs/snapshot/<files>
    serviceConfig.WorkingDirectory = "${mountPoint}/.zfs/snapshot/";
  };

  # --- T7 SSD ------------------------------------------------------
  systemd.services."restic-backups-t7" = {
    unitConfig = {
      RequiresMountsFor = ["${mountPoint}" "/mnt/t7"]; # Fail if /nas + /mnt/t7 are not mounted
      After = ["network-online.target"]; # Internet required
      Wants = ["network-online.target"]; # Internet Required
      OnFailure = ["notify-backup-failed@%n.service"]; # "%n" becomes "restic-backups-[b2|t7]"
    };
    # Allows us to use ./<snapshot> as restic path
    # See (<mountpoint>/<files>) instead of <mountpoint>/nas/.zfs/snapshot/<files>
    serviceConfig.WorkingDirectory = "${mountPoint}/.zfs/snapshot/";
  };

  # -----------------------------------------------------------------------------------------------
  # On Backup Failed Service
  # For more details: https://manpages.ubuntu.com/manpages/xenial/man5/systemd.unit.5.html

  systemd.services."notify-backup-failed@" = {
    description = "Send ntfy alert when %i fails";
    restartIfChanged = false; # it’s oneshot; no need to restart on config change
    serviceConfig.Type = "oneshot";
    scriptArgs = "%i"; # %i → failed-unit name becomes $1 in the shell
    path = with pkgs; [ntfy-sh coreutils];

    script = ''
      failed="$1"
      logs=$(journalctl -u "$failed" -n 20 -o cat)
      echo "$logs"
      ${notify ''$failed failed!''} # Yell out who failed
    '';
  };

  # -----------------------------------------------------------------------------------------------
  # Restic config
  services.restic.backups = {
    b2 = {
      initialize = true; # Create repo if it doesn't exist
      inhibitsSleep = true;

      environmentFile = config.sops.secrets."backup/b2.env".path;
      repositoryFile = config.sops.secrets."backup/b2/restic/repo".path;
      passwordFile = config.sops.secrets."backup/b2/restic/password".path;

      paths = ["./${snapshotName}"];
      # exclude = [];

      # Create snapshot of the dataset. They will be named <dataset-mountpoint>@<snapshotName>
      backupPrepareCommand = ''
        ${notify "B2 Backup started"}
        ${pkgs.bash}/bin/bash ${./create-snapshots.sh} ${pkgs.zfs}/bin/zfs ${backupDataset} ${snapshotName}
      '';

      backupCleanupCommand = ''
        ${pkgs.bash}/bin/bash ${./cleanup-snapshots.sh} ${pkgs.zfs}/bin/zfs ${backupDataset} ${snapshotName}
        ${notify "B2 Backup complete"}
      '';

      extraBackupArgs = [
        "--tag=nas"
        "--one-file-system"
        "--limit-upload 10000" # speed limit
        # "--verbose=2"
      ];

      pruneOpts = [
        # "--keep-daily 24"
        "--keep-weekly 7"
        "--keep-monthly 6"
      ];

      timerConfig = {
        # OnCalendar = "Sun *-*-* 03:01:00"; # Weekly backup on Sundays at 3:01 AM
        OnCalendar = "03:01:00"; # Daily backup at 3:01 AM
      };
    };
    t7 = {
      initialize = true; # Create repo if it doesn't exist
      inhibitsSleep = true;

      passwordFile = config.sops.secrets."backup/t7-password".path;
      repository = "/mnt/t7/restic";

      paths = ["./${snapshotName}"];
      # exclude = [];

      # Create snapshot of the dataset. They will be named <dataset-mountpoint>@<snapshotName>
      backupPrepareCommand = ''
        ${notify "T7 Backup started"}
        ${pkgs.bash}/bin/bash ${./create-snapshots.sh} ${pkgs.zfs}/bin/zfs ${backupDataset} ${snapshotName}
      '';

      backupCleanupCommand = ''
        ${pkgs.bash}/bin/bash ${./cleanup-snapshots.sh} ${pkgs.zfs}/bin/zfs ${backupDataset} ${snapshotName}
        ${notify "T7 Backup complete"}
      '';

      extraBackupArgs = [
        "--tag=nas"
        "--one-file-system"
        # "--verbose=2"
      ];

      pruneOpts = [
        # "--keep-daily 24"
        "--keep-weekly 7"
        "--keep-monthly 6"
      ];

      timerConfig = {
        OnCalendar = "02:01:00"; # Daily backup at 2:01 AM
      };
    };
  };
}
