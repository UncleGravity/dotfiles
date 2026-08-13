#!/usr/bin/env bash
set -euo pipefail

umask 077

# Install NixOS with an escrowed host identity; erases the target disk.

usage() {
  echo "Usage: $0 <hostname> <ssh-target>   e.g. $0 portal root@1.2.3.4" >&2
  exit 2
}

(($# == 2)) || usage
host=$1
target=$2
repo_root=$(git rev-parse --show-toplevel)

case $host in
portal | sisyphus) ;;
kiwi)
  echo "Kiwi reinstall is intentionally not automated: its Disko graph includes the storage pool." >&2
  echo "Stop and design a reviewed OS-disk-only recovery; see docs/reinstall.md." >&2
  exit 1
  ;;
spark-01 | spark-02 | spark-03 | spark-04)
  echo "Use 'just spark-install $host' for DGX Spark hardware." >&2
  exit 1
  ;;
*)
  echo "Generic provisioning is unsupported for '$host'." >&2
  exit 1
  ;;
esac

echo "This will ERASE the disk on $target and install '$host' from this flake."
read -r -p "Type $host to continue: " confirmation
if [[ $confirmation != "$host" ]]; then
  echo "Confirmation did not match; aborting." >&2
  exit 1
fi

extra_files=$(mktemp -d)
trap 'rm -rf "$extra_files"' EXIT
"$repo_root/scripts/stage-install-secrets.sh" "$host" "$extra_files"

nixos-anywhere --flake "$repo_root#$host" \
  --target-host "$target" \
  --extra-files "$extra_files" \
  --build-on remote \
  --option builders ""
