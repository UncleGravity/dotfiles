#!/usr/bin/env bash
set -euo pipefail

# Usage: create-snapshots.sh <zfs_binary_path> <dataset> <snapshot_name>

log() { echo "(pre-backup hook) $*"; }

if (( $# != 3 )); then
  log "Usage: $0 <zfs_binary_path> <dataset> <snapshot_name>"
  exit 1
fi

readonly ZFS=$1
readonly DATASET=$2
readonly SNAPSHOT_NAME=$3
readonly SNAPSHOT="${DATASET}@${SNAPSHOT_NAME}"

if [[ ! -x "$ZFS" ]]; then
  log "ERROR: '$ZFS' is not executable"
  exit 1
fi

if "$ZFS" list -H -t snapshot -o name "$SNAPSHOT" &>/dev/null; then
  log "ERROR: $SNAPSHOT already exists; aborting"
  exit 1
fi

if ! "$ZFS" snapshot "$SNAPSHOT"; then
  log "ERROR: failed to create $SNAPSHOT"
  exit 1
fi

mountpoint=$("$ZFS" get -H -o value mountpoint "$DATASET")
snapshot_path="$mountpoint/.zfs/snapshot/$SNAPSHOT_NAME"

if [[ ! -d "$snapshot_path" ]]; then
  log "ERROR: snapshot is not accessible at $snapshot_path"
  exit 1
fi

# Force ZFS to automount the snapshot before Restic applies --one-file-system.
if ! ls -A "$snapshot_path" >/dev/null; then
  log "ERROR: failed to access snapshot contents at $snapshot_path"
  exit 1
fi

log "Created $SNAPSHOT at $snapshot_path"
