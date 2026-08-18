#!/usr/bin/env bash
set -euo pipefail

# Usage: cleanup-snapshots.sh <zfs_binary_path> <dataset> <snapshot_name>

log() { echo "(post-backup hook) $*"; }

if (($# != 3)); then
  log "Usage: $0 <zfs_binary_path> <dataset> <snapshot_name>"
  exit 1
fi

readonly ZFS=$1
readonly DATASET=$2
readonly SNAPSHOT_NAME=$3
readonly SNAPSHOT="${DATASET}@${SNAPSHOT_NAME}"

[[ -x $ZFS ]] || {
  log "ERROR: '$ZFS' is not executable"
  exit 1
}

if ! "$ZFS" list -H -o name "$DATASET" &>/dev/null; then
  log "ERROR: dataset $DATASET is not accessible"
  exit 1
fi

if ! "$ZFS" list -H -t snapshot -o name "$SNAPSHOT" &>/dev/null; then
  log "$SNAPSHOT is not present; nothing to do"
  exit 0
fi

log "Destroying $SNAPSHOT"
if ! "$ZFS" destroy -d "$SNAPSHOT"; then
  log "ERROR: failed to destroy $SNAPSHOT"
  exit 1
fi

log "Destroyed or marked $SNAPSHOT for deferred destruction"
