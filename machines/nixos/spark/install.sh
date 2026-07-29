#!/usr/bin/env bash
set -euo pipefail

umask 077

usage() {
	echo "Usage: $0 <spark-01|spark-02|spark-03|spark-04>" >&2
	echo "Run against a node booted into the NixOS USB installer (see README)." >&2
	exit 2
}

(($# == 1)) || usage
node=$1
repo_root=$(git rev-parse --show-toplevel)
cache_url=https://unclegravity-nix.cachix.org
cache_key=unclegravity-nix.cachix.org-1:fnXTPHMhvKwMrqyU/z00iyf8SkUuK0YP2PpCYb1t3nI=

ip=$(nix eval --raw "$repo_root#sparkNodes.$node.managementAddress" 2>/dev/null) || {
	echo "Unknown Spark node: $node" >&2
	exit 1
}

extra_files=$(mktemp -d)
trap 'rm -rf -- "$extra_files"' EXIT
"$repo_root/scripts/host-key.sh" stage "$node" "$extra_files"

echo "This will ERASE the NVMe on $node ($ip) and install NixOS."
read -r -p "Type $node to continue: " confirmation
if [[ $confirmation != "$node" ]]; then
	echo "Confirmation did not match; aborting." >&2
	exit 1
fi

nixos-anywhere --flake "$repo_root#$node" --target-host "root@$ip" \
	--extra-files "$extra_files" \
	--build-on remote \
	--option extra-substituters "$cache_url" \
	--option extra-trusted-public-keys "$cache_key" \
	--phases disko,install,reboot
