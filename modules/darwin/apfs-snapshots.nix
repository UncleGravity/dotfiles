{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.apfs-snapshots;
in
{
  options.my.apfs-snapshots = {
    enable = mkEnableOption "APFS snapshot management service";

    interval = mkOption {
      type = types.int;
      default = 3600;
      description = "Interval in seconds between snapshots (default: 3600 = 1 hour)";
    };

    keepCount = mkOption {
      type = types.int;
      default = 24;
      description = "Number of snapshots to keep (default: 24)";
    };

    logPath = mkOption {
      type = types.str;
      default = "/var/log/apfs-snapshots.log";
      description = "Path to log file for snapshot operations";
    };
  };

  config = mkIf cfg.enable {
    launchd.daemons.apfs-snapshots = {
      path = [ pkgs.ripgrep pkgs.bash pkgs.coreutils ];
      serviceConfig = {
        ProgramArguments = [
          "${pkgs.bash}/bin/bash" "-c"
          ''
            # take a new APFS local snapshot
            /usr/bin/tmutil snapshot

            # list just the timestamp strings, sort oldest→newest
            # Filter out the header line "Snapshot dates for disk /:"
            snapshots=$(
              /usr/bin/tmutil listlocalsnapshotdates / \
              | rg '^\d{4}-\d{2}-\d{2}-\d{6}$' \
              | sort
            )

            # count total snapshots (only count non-empty lines)
            total_count=$(echo "$snapshots" | rg -c '^\d' || echo "0")

            # only delete if we have more than the keep count
            if [ "$total_count" -gt ${toString cfg.keepCount} ]; then
              # calculate how many to delete
              delete_count=$((total_count - ${toString cfg.keepCount}))

              # delete the oldest snapshots
              echo "$snapshots" \
                | head -n "$delete_count" \
                | while read ts; do
                    if [ -n "$ts" ]; then
                      echo "$(date): Deleting snapshot: $ts"
                      /usr/bin/tmutil deletelocalsnapshots "$ts"
                    fi
                  done
            else
              echo "$(date): Total snapshots ($total_count) &lt;= keep count (${toString cfg.keepCount}), no deletion needed"
            fi

            echo "$(date): Snapshot operation completed"
          ''
        ];
        StartInterval = cfg.interval;
        StandardOutPath = cfg.logPath;
        StandardErrorPath = cfg.logPath;
        # Ensure the service runs even when no user is logged in
        RunAtLoad = true;
        # Service should stop when snapshot operation is completed
        # We be reinvoked when timer interval is reached again
        KeepAlive = false;
      };
    };

    # Ensure log directory exists
    system.activationScripts.apfs-snapshots-log = ''
      mkdir -p "$(dirname "${cfg.logPath}")"
      touch "${cfg.logPath}"
      chmod 644 "${cfg.logPath}"
    '';
  };
}
