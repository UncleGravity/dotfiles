#!/usr/bin/env bash
set -euo pipefail

# Script to destroy a snapshot on a single ZFS dataset after backup.
# Usage: destroy-snapshot.sh <zfs_binary_path> <dataset> <snapshot_name>

log() { echo "(post-backup hook) $*"; }

# -------- argument handling ---------
if [ "$#" -ne 3 ]; then
  log "Usage: $0 <zfs_binary_path> <dataset> <snapshot_name>"
  exit 1
fi

ZFS=$1
DATASET=$2
SNAPSHOT_NAME=$3

[ -x "$ZFS" ] || {
  log "ERROR: '$ZFS' is not executable"
  exit 1
}
# ------------------------------------
# For some reason accessing the snapshot helps the stability of the backup script
# MOUNTPOINT=$("$ZFS" get -H -o value mountpoint "$DATASET")
# ls "$MOUNTPOINT/.zfs/snapshot/${SNAPSHOT_NAME}"

log "Requesting deferred destroy of ${DATASET}@${SNAPSHOT_NAME}"
sleep 5 # We gotta wait for the snapshot to get relased
if "$ZFS" destroy -d "${DATASET}@${SNAPSHOT_NAME}" 2>/dev/null; then
  log "Destroy (deferred) issued for ${DATASET}@${SNAPSHOT_NAME}"
else
  log "Snapshot not present or already in deferred state; nothing to do"
fi
