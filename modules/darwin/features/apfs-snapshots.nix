{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.my.apfs-snapshots;
in {
  ##### 1. Options #############################################################
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

  ##### 2. Implementation ######################################################
  config = mkIf cfg.enable {
    launchd.daemons.apfs-snapshots = {
      path = [pkgs.ripgrep pkgs.coreutils];
      script = ''
        log() { echo "[$(date '+%Y-%m-%dT%H:%M:%S%z')] $1: $2"; }

        # take a new APFS local snapshot
        log INFO "Creating snapshot"
        /usr/bin/tmutil snapshot /

        # list just the timestamp strings, sort oldest→newest
        # Filter out the header line "Snapshot dates for disk /:"
        snapshots=$(
          /usr/bin/tmutil listlocalsnapshotdates / \
          | rg '^\d{4}-\d{2}-\d{2}-\d{6}$' \
          | sort
        )

        total_count=$(printf '%s\n' "$snapshots" | rg -c '^\d' || true)
        total_count=''${total_count:-0}

        # nothing to prune — exit early
        if [ "$total_count" -le ${toString cfg.keepCount} ]; then
          log INFO "$total_count snapshots <= ${toString cfg.keepCount}, skipping"
          exit 0
        fi

        # delete the oldest snapshots
        delete_count=$((total_count - ${toString cfg.keepCount}))
        echo "$snapshots" \
          | head -n "$delete_count" \
          | while read ts; do
              [ -n "$ts" ] || continue
              log INFO "Deleting snapshot: $ts"
              /usr/bin/tmutil deletelocalsnapshots "$ts" || log ERROR "Failed to delete: $ts"
            done

        log INFO "Snapshot operation completed"

        # simple log rotation: keep last 500 lines
        tail -n 500 "${cfg.logPath}" > "${cfg.logPath}.tmp" && mv "${cfg.logPath}.tmp" "${cfg.logPath}"
      '';
      serviceConfig = {
        StartInterval = cfg.interval;
        StandardOutPath = cfg.logPath;
        StandardErrorPath = cfg.logPath;
        RunAtLoad = true; # Ensure service runs even when no user is logged in
      };
    };
  };
}
