{
  config,
  hostname,
  lib,
  pkgs,
  ...
}: let
  backupDataset = "storagepool/share";
  mountPoint = "/srv/share";
  ntfy = lib.getExe pkgs.ntfy-sh;
  ntfyTitle = "${hostname} Backup";
  ntfyTopicFile = config.clan.core.vars.generators.ntfy.files.topic.path;

  notify = message: ''NTFY_TOPIC="$(<${ntfyTopicFile})" ${ntfy} pub -m ${lib.escapeShellArg message} -t ${lib.escapeShellArg ntfyTitle}'';

  mkBackup = {
    extraBackupArgs ? [],
    label,
    name,
    onCalendar,
  }: let
    snapshotName = "backup-${name}";
  in {
    initialize = true;
    inhibitsSleep = true;

    paths = ["./${snapshotName}"];

    backupPrepareCommand = ''
      ${notify "${label} Backup started"} || true
      ${pkgs.bash}/bin/bash ${./create-snapshots.sh} ${pkgs.zfs}/bin/zfs ${backupDataset} ${snapshotName}
    '';

    backupCleanupCommand = ''
      ${pkgs.bash}/bin/bash ${./cleanup-snapshots.sh} ${pkgs.zfs}/bin/zfs ${backupDataset} ${snapshotName}
    '';

    extraBackupArgs =
      [
        "--tag=nas"
        "--group-by=host,tags"
        "--one-file-system"
      ]
      ++ extraBackupArgs;

    pruneOpts = [
      "--group-by=host,tags"
      "--keep-weekly=7"
      "--keep-monthly=6"
    ];

    timerConfig = {
      OnCalendar = onCalendar;
      Persistent = true;
    };
  };

  mkResticService = requiredMounts: {
    unitConfig = {
      RequiresMountsFor = requiredMounts;
      OnFailure = ["notify-backup-failed@%N.service"];
      OnSuccess = ["notify-backup-success@%N.service"];
    };
    serviceConfig.WorkingDirectory = "${mountPoint}/.zfs/snapshot";
  };
in {
  clan.core.vars.generators.backup-b2 = {
    prompts = {
      environment = {
        description = "B2 environment file";
        type = "multiline-hidden";
        persist = true;
      };
      repository = {
        description = "B2 Restic repository";
        type = "hidden";
        persist = true;
      };
      password = {
        description = "B2 Restic repository password";
        type = "hidden";
        persist = true;
      };
    };
    files = lib.genAttrs ["environment" "repository" "password"] (_: {
      owner = "root";
      group = "root";
      mode = "0400";
      restartUnits = ["prometheus-restic-exporter-b2.service"];
    });
    script = ''
      test -s "$out/environment"
      for name in repository password; do
        test -s "$out/$name"
        test "$(tr -cd '\r\n' < "$out/$name" | wc -c)" -eq 0
      done
    '';
  };

  sops.secrets."backup/t7-password" = {};

  systemd.services = {
    "restic-backups-b2" = mkResticService [mountPoint];
    "restic-backups-t7" = mkResticService [mountPoint "/mnt/t7"];

    "notify-backup-success@" = {
      description = "Send ntfy alert when %i completes";
      serviceConfig.Type = "oneshot";
      scriptArgs = "%i";
      script = ''
        unit="$1"
        NTFY_TOPIC="$(<${ntfyTopicFile})" ${ntfy} pub \
          -m "$unit completed successfully" \
          -t ${lib.escapeShellArg ntfyTitle}
      '';
    };

    "notify-backup-failed@" = {
      description = "Send ntfy alert when %i fails";
      serviceConfig.Type = "oneshot";
      scriptArgs = "%i";
      script = ''
        unit="$1"
        logs="$(journalctl -u "$unit.service" -n 20 -o cat --no-pager | tail -c 3000 || true)"
        message="$unit failed"
        if [[ -n "$logs" ]]; then
          message+=$'\n\n'"$logs"
        fi
        NTFY_TOPIC="$(<${ntfyTopicFile})" ${ntfy} pub \
          -m "$message" \
          -t ${lib.escapeShellArg ntfyTitle}
      '';
    };
  };

  services.restic.backups = {
    b2 =
      mkBackup {
        name = "b2";
        label = "B2";
        onCalendar = "03:01:00";
        extraBackupArgs = ["--limit-upload=10000"];
      }
      // {
        environmentFile = config.clan.core.vars.generators.backup-b2.files.environment.path;
        repositoryFile = config.clan.core.vars.generators.backup-b2.files.repository.path;
        passwordFile = config.clan.core.vars.generators.backup-b2.files.password.path;
      };

    t7 =
      mkBackup {
        name = "t7";
        label = "T7";
        onCalendar = "02:01:00";
      }
      // {
        passwordFile = config.sops.secrets."backup/t7-password".path;
        repository = "/mnt/t7/restic";
      };
  };
}
