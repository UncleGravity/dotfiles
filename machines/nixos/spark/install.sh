#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <spark-01|spark-02|spark-03|spark-04>" >&2
  echo "Run against a node booted into the NixOS USB installer (see README)." >&2
  exit 2
}

(($# == 1)) || usage
node=$1

ip=$(nix eval --raw ".#sparkNodes.$node.managementAddress" 2>/dev/null) || {
  echo "Unknown Spark node: $node" >&2
  exit 1
}

echo "This will ERASE the NVMe on $node ($ip) and install NixOS."
read -r -p "Type $node to continue: " confirmation
if [[ $confirmation != "$node" ]]; then
  echo "Confirmation did not match; aborting." >&2
  exit 1
fi

# # A USB-booted installer has freshly generated host keys. Restore the node's
# # original ones (stashed from DGX OS) so --copy-host-keys preserves the host
# # identity that .sops.yaml and known_hosts rely on.
# stash=$HOME/.ssh/spark-host-keys/$node
# if [[ -d $stash ]]; then
#   scp -O "$stash"/ssh_host_* "root@$ip:/etc/ssh/"
# fi

# Let the installer substitute the NVIDIA kernel and drivers from the personal
# cache (populated with `just spark-cache`) instead of compiling on-device.
ssh "root@$ip" "printf '%s\n' \
  'extra-substituters = https://unclegravity-nix.cachix.org' \
  'extra-trusted-public-keys = unclegravity-nix.cachix.org-1:fnXTPHMhvKwMrqyU/z00iyf8SkUuK0YP2PpCYb1t3nI=' \
  >> /etc/nix/nix.conf"

exec nixos-anywhere --flake ".#$node" --target-host "root@$ip" \
  --copy-host-keys --build-on remote --phases disko,install,reboot
