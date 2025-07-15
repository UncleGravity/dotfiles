#!/usr/bin/env bash
set -euo pipefail

# Script to resolve ZFS snapshot path for backup, used by restic's dynamicFilesFrom.
# It takes the path to the zfs binary as its first argument, followed by the dataset and snapshot name.
# Usage: resolve-snapshot-paths.sh <zfs_binary_path> <dataset> <snapshot_name>

# Logging function (to stderr so it doesn't interfere with the file list output)
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] (dynamic-files) $1" >&2
}

if [ $# -ne 3 ]; then
  log "ERROR: Insufficient arguments. A zfs binary path, dataset, and snapshot name are required."
  echo "Usage: $0 <zfs_binary_path> <dataset> <snapshot_name>" >&2
  exit 1
fi

ZFS_CMD="$1"
DATASET="$2"
SNAPSHOT_NAME="$3"

log "Starting ZFS snapshot path resolution for dataset: $DATASET"

log "Processing dataset: $DATASET"

# Check if the snapshot exists
if ! "$ZFS_CMD" list -t snapshot -H -o name | grep -q "^${DATASET}@${SNAPSHOT_NAME}$"; then
  log "ERROR: Snapshot not found: ${DATASET}@${SNAPSHOT_NAME}"
  exit 1
fi

# Get the mountpoint for the dataset
if ! MOUNTPOINT=$("$ZFS_CMD" get -H -o value mountpoint "$DATASET" 2>/dev/null); then
  log "ERROR: Failed to get mountpoint for dataset: $DATASET"
  exit 1
fi

# Construct the snapshot path
SNAPSHOT_PATH="$MOUNTPOINT/.zfs/snapshot/${SNAPSHOT_NAME}"

log "Dataset: $DATASET, Mountpoint: $MOUNTPOINT"
log "Checking snapshot path: $SNAPSHOT_PATH"

# Check if the snapshot directory exists and is accessible
if [ -d "$SNAPSHOT_PATH" ]; then
  log "Found snapshot directory: $SNAPSHOT_PATH"
  # Print directory listing
  log "Directory contents:"
  ls -la "$SNAPSHOT_PATH" 2>&1 | while read line; do
    log "  $line"
  done
  # Output the path to stdout (this is what restic will use)
  echo "$SNAPSHOT_PATH"
else
  log "ERROR: Snapshot directory not found or not accessible: $SNAPSHOT_PATH"
  exit 1
fi

log "ZFS snapshot path resolution completed successfully"
