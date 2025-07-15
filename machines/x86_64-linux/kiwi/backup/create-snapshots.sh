#!/usr/bin/env bash
set -euo pipefail

# Script to create ZFS snapshot for backup.
# It takes the path to the zfs binary as its first argument, followed by the dataset and snapshot name.
# Usage: create-snapshots.sh <zfs_binary_path> <dataset> <snapshot_name>

log() { echo "(pre-backup hook) $*"; }

# ---------------------- argument handling ----------------------
if [ $# -ne 3 ]; then
  log "Usage: $0 <zfs_binary_path> <dataset> <snapshot_name>"
  exit 1
fi

ZFS=$1
DATASET=$2
SNAPSHOT_NAME=$3

if [ ! -x "$ZFS" ]; then
  log "ERROR: '$ZFS' is not executable"
  exit 1
fi
# ---------------------------------------------------------------

log "Processing $DATASET"

# ---- hard fail if snapshot already exists ----
if "$ZFS" list -H -o name "${DATASET}@${SNAPSHOT_NAME}" &>/dev/null; then
  log "ERROR: ${DATASET}@${SNAPSHOT_NAME} already exists; aborting."
  exit 1
fi
# ---------------------------------------------

if "$ZFS" snapshot "${DATASET}@${SNAPSHOT_NAME}"; then
  sleep 1
  log "Created ${DATASET}@${SNAPSHOT_NAME}"

  # For some reason accessing the snapshot helps the stability of the backup script
  MOUNTPOINT=$("$ZFS" get -H -o value mountpoint "$DATASET")
  ls "$MOUNTPOINT/.zfs/snapshot/${SNAPSHOT_NAME}"
else
  log "ERROR: failed to create ${DATASET}@${SNAPSHOT_NAME}"
  exit 1
fi

log "Snapshot created successfully"
